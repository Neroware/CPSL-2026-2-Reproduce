#!/usr/bin/env python3
"""Compare a test SPARQL endpoint's answers against a reference endpoint's.

Runs every concrete BSBM query instance found in a test-driver qualification
log (run.log, see gen-correctness-queries.sh) against both endpoints and
classifies the test endpoint's answer per instance. Driven by
run-correctness.sh, which runs this inside the bsbm-tools container (needs
only the Python stdlib plus rdflib).

Statuses, most severe first:
  error              HTTP error, timeout or unparsable response
  wrong_vars         SELECT head differs from the reference
  count_mismatch     different number of rows / triples
  content_mismatch   same count, different rows / triples
  wrong_order        right rows, but not sorted by the ORDER BY keys
  unsupported        empty graph where the reference has triples (DESCRIBE/CONSTRUCT)
  match_modulo_ties  ORDER BY ... LIMIT picked a different but equally valid
                     subset of rows tied at the cut-off
  match              same rows (as a multiset, or as a list under ORDER BY)

DESCRIBE output is implementation-defined (SPARQL 1.1 sec. 16.4), and GengoDB
has no real CONSTRUCT/DESCRIBE support, so both are flagged "informational"
in the summary rather than counted as plain correctness failures.

Usage:
  check-correctness.py --queries run.log --reference URL --test URL
                       --out DIR [--ref-cache DIR] [--timeout S]
"""
import argparse
import csv
import functools
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from collections import Counter

SR = "{http://www.w3.org/2005/sparql-results#}"
XSD = "http://www.w3.org/2001/XMLSchema#"
NUMERIC_TYPES = {XSD + t for t in (
    "integer", "decimal", "double", "float", "int", "long", "short", "byte",
    "nonNegativeInteger", "positiveInteger", "negativeInteger", "nonPositiveInteger",
    "unsignedInt", "unsignedLong", "unsignedShort", "unsignedByte")}
STATUSES = ["match", "match_modulo_ties", "wrong_order", "unsupported",
            "content_mismatch", "count_mismatch", "wrong_vars", "error"]
SEVERITY = {s: i for i, s in enumerate(STATUSES)}
INFORMATIONAL_TYPES = {"DESCRIBE", "CONSTRUCT"}
MAX_DIFF_ROWS = 5


# --- Query instances -------------------------------------------------------

INSTANCE_RE = re.compile(
    r"\tQuery (\d+) of run \d+:\n\n\tQuery string:\n\n(.*?)\n\n\tResult:", re.S)


def parse_instances(log_path):
    with open(log_path, encoding="utf-8") as f:
        text = f.read()
    return [(int(m.group(1)), m.group(2).strip()) for m in INSTANCE_RE.finditer(text)]


def query_type(q):
    body = re.sub(r"(?im)^\s*(PREFIX|BASE)\s+[^\n]*$", "", q)
    m = re.search(r"\b(SELECT|CONSTRUCT|DESCRIBE|ASK)\b", body, re.I)
    return m.group(1).upper() if m else "UNKNOWN"


def order_keys(q):
    """[(var, descending, numeric_cast)] for the top-level ORDER BY, or []."""
    m = re.search(r"\bORDER\s+BY\s+(.*?)(?:\bLIMIT\b|\bOFFSET\b|$)", q, re.I | re.S)
    if not m:
        return []
    keys = []
    for tok in re.finditer(r"(DESC|ASC)?\s*\(?\s*((?:xsd:\w+\s*\(\s*)?(?:str\s*\(\s*)?)\?(\w+)",
                           m.group(1), re.I):
        keys.append((tok.group(3), (tok.group(1) or "").upper() == "DESC",
                     "xsd:" in tok.group(2).lower()))
    return keys


def has_limit(q):
    return re.search(r"\b(LIMIT|OFFSET)\s+\d+\s*$", q, re.I) is not None


def strip_limit_offset(q):
    prev = None
    while prev != q:
        prev = q
        q = re.sub(r"\s*\b(LIMIT|OFFSET)\s+\d+\s*$", "", q, flags=re.I)
    return q


def limit_offset(q):
    lim = re.search(r"\bLIMIT\s+(\d+)", q, re.I)
    off = re.search(r"\bOFFSET\s+(\d+)", q, re.I)
    return (int(lim.group(1)) if lim else None), (int(off.group(1)) if off else 0)


# --- HTTP ----------------------------------------------------------------

def fetch(endpoint, q, accept, timeout):
    url = endpoint + "?" + urllib.parse.urlencode({"query": q})
    req = urllib.request.Request(url, headers={"Accept": accept})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read(), resp.headers.get("Content-Type", "")


class RefCache:
    """Reference answers on disk, keyed by query text, so re-checking a new
    GengoDB build doesn't need to re-query the reference endpoint."""

    def __init__(self, directory):
        self.dir = directory
        if directory:
            os.makedirs(directory, exist_ok=True)

    def get(self, endpoint, q, accept, timeout):
        if not self.dir:
            return fetch(endpoint, q, accept, timeout)
        key = hashlib.sha1((accept + "\n" + q).encode()).hexdigest()
        body_path = os.path.join(self.dir, key + ".body")
        ctype_path = os.path.join(self.dir, key + ".ctype")
        if os.path.exists(body_path) and os.path.exists(ctype_path):
            with open(body_path, "rb") as f, open(ctype_path) as g:
                return f.read(), g.read()
        body, ctype = fetch(endpoint, q, accept, timeout)
        with open(body_path, "wb") as f, open(ctype_path, "w") as g:
            f.write(body)
            g.write(ctype)
        return body, ctype


# --- SELECT results ----------------------------------------------------------

UNBOUND = ("U",)


def norm_term(el):
    tag = el.tag.replace(SR, "")
    text = el.text or ""
    if tag == "uri":
        return ("I", text)
    if tag == "bnode":
        return ("B",)  # labels are not comparable across stores
    lang = el.get("{http://www.w3.org/XML/1998/namespace}lang")
    dt = el.get("datatype")
    if lang:
        return ("L", text, None, lang.lower())
    if dt in NUMERIC_TYPES:
        try:
            return ("N", format(float(text), ".12g"))
        except ValueError:
            return ("L", text, dt, None)
    if dt in (None, XSD + "string"):
        return ("L", text, None, None)
    if dt == XSD + "boolean":
        return ("L", text.strip().lower(), dt, None)
    if dt in (XSD + "dateTime", XSD + "date"):
        return ("L", re.sub(r"(Z|\+00:00)$", "", text.strip()), dt, None)
    return ("L", text, dt, None)


def parse_select(body):
    root = ET.fromstring(body)
    head = root.find(SR + "head")
    variables = [v.get("name") for v in head.findall(SR + "variable")]
    rows = []
    for res in root.find(SR + "results").findall(SR + "result"):
        row = {}
        for b in res.findall(SR + "binding"):
            row[b.get("name")] = norm_term(list(b)[0])
        rows.append(row)
    return variables, rows


def row_tuple(row, variables):
    return tuple(row.get(v, UNBOUND) for v in variables)


def sort_key_part(term, numeric):
    # SPARQL ordering: unbound < bnode < IRI < literal.
    if term[0] == "U":
        return (0, 0, "")
    if term[0] == "B":
        return (1, 0, "")
    if term[0] == "I":
        return (2, 0, term[1])
    value = term[1]
    if term[0] == "N" or numeric:
        try:
            return (3, float(value), "")
        except ValueError:
            pass
    return (3, 0, value)


def order_tuple(row, keys):
    out = []
    for var, desc, numeric in keys:
        k = sort_key_part(row.get(var, UNBOUND), numeric)
        out.append(k)
    return out


def compare_keys(a, b, keys):
    """-1/0/1 comparing two row keys under the ORDER BY directions."""
    for (ka, kb, (_, desc, _)) in zip(a, b, keys):
        if ka == kb:
            continue
        less = (ka > kb) if desc else (ka < kb)
        return -1 if less else 1
    return 0


def in_order(a, b, keys):
    """True if row-key a may precede row-key b."""
    return compare_keys(a, b, keys) <= 0


def show_rows(rows, variables):
    out = []
    for r in rows[:MAX_DIFF_ROWS]:
        out.append({v: list(t) for v, t in zip(variables, r)})
    return out


def compare_select(q, ref, test, ref_full):
    """ref/test/ref_full: (variables, rows). ref_full is the reference answer
    with LIMIT/OFFSET stripped (only needed for ORDER BY ... LIMIT)."""
    ref_vars, ref_rows = ref
    test_vars, test_rows = test
    info = {"ref_count": len(ref_rows), "test_count": len(test_rows)}
    if sorted(ref_vars) != sorted(test_vars):
        info["detail"] = {"ref_vars": ref_vars, "test_vars": test_vars}
        return "wrong_vars", info

    variables = sorted(ref_vars)
    ref_t = [row_tuple(r, variables) for r in ref_rows]
    test_t = [row_tuple(r, variables) for r in test_rows]
    ref_c, test_c = Counter(ref_t), Counter(test_t)

    keys = [k for k in order_keys(q) if k[0] in variables]
    ordered_ok = True
    if keys:
        tk = [order_tuple(r, keys) for r in test_rows]
        ordered_ok = all(in_order(tk[i], tk[i + 1], keys) for i in range(len(tk) - 1))

    if ref_c == test_c:
        return ("match" if ordered_ok else "wrong_order"), info

    missing = list((ref_c - test_c).elements())
    extra = list((test_c - ref_c).elements())
    info["detail"] = {"missing": show_rows(missing, variables),
                      "extra": show_rows(extra, variables),
                      "n_missing": len(missing), "n_extra": len(extra)}

    if len(ref_rows) != len(test_rows):
        return "count_mismatch", info

    # Same size, different rows: with ORDER BY ... LIMIT, ties at the cut-off
    # can legitimately select different rows. Valid iff the test rows are
    # sorted, have the same sequence of sort keys as the reference window,
    # and every row exists in the full (un-limited) reference answer with
    # that key.
    if keys and ref_full is not None and ordered_ok:
        _, full_rows = ref_full
        lim, off = limit_offset(q)
        cmp = functools.cmp_to_key(lambda a, b: compare_keys(a[0], b[0], keys))
        full_keyed = sorted(((tuple(order_tuple(r, keys)), row_tuple(r, variables))
                             for r in full_rows), key=cmp)
        # Expected key sequence comes from the full answer, so it doesn't
        # depend on how the reference happened to break ties.
        window = full_keyed[off:off + lim] if lim is not None else full_keyed[off:]
        test_keyed = [(tuple(order_tuple(r, keys)), t) for r, t in zip(test_rows, test_t)]
        if [k for k, _ in window] == [k for k, _ in test_keyed] and \
                not (Counter(test_keyed) - Counter(full_keyed)):
            return "match_modulo_ties", info

    return "content_mismatch", info


# --- Graph results (CONSTRUCT / DESCRIBE) --------------------------------------

def parse_graph(body, ctype):
    import rdflib
    fmt = "xml"
    c = ctype.lower()
    if "turtle" in c:
        fmt = "turtle"
    elif "n-triples" in c or "ntriples" in c:
        fmt = "nt"
    elif "json" in c:
        fmt = "json-ld"
    g = rdflib.Graph()
    if body.strip():
        g.parse(data=body, format=fmt)
    return g


def compare_graph(ref_g, test_g):
    from rdflib.compare import to_isomorphic, graph_diff
    info = {"ref_count": len(ref_g), "test_count": len(test_g)}
    if len(test_g) == 0 and len(ref_g) > 0:
        return "unsupported", info
    iso_ref, iso_test = to_isomorphic(ref_g), to_isomorphic(test_g)
    if iso_ref == iso_test:
        return "match", info
    _, only_ref, only_test = graph_diff(iso_ref, iso_test)
    info["detail"] = {
        "n_missing": len(only_ref), "n_extra": len(only_test),
        "missing": [" ".join(t.n3() for t in tr) for tr in list(only_ref)[:MAX_DIFF_ROWS]],
        "extra": [" ".join(t.n3() for t in tr) for tr in list(only_test)[:MAX_DIFF_ROWS]],
    }
    return ("count_mismatch" if len(ref_g) != len(test_g) else "content_mismatch"), info


# --- Driver --------------------------------------------------------------------

def check_instance(seq, qnr, q, args, ref_cache):
    qtype = query_type(q)
    rec = {"seq": seq, "query": qnr, "type": qtype,
           "sha1": hashlib.sha1(q.encode()).hexdigest()[:12]}
    accept = ("application/sparql-results+xml" if qtype in ("SELECT", "ASK")
              else "application/rdf+xml")

    try:
        ref_body, ref_ctype = ref_cache.get(args.reference, q, accept, args.timeout)
    except Exception as e:  # reference failing is a harness problem, not a test failure
        rec.update(status="error", side="reference", detail=repr(e))
        return rec

    t0 = time.monotonic()
    try:
        test_body, test_ctype = fetch(args.test, q, accept, args.timeout)
    except urllib.error.HTTPError as e:
        rec.update(status="error", side="test", detail="HTTP %d" % e.code)
        return rec
    except Exception as e:
        rec.update(status="error", side="test", detail=repr(e))
        return rec
    rec["test_seconds"] = round(time.monotonic() - t0, 4)

    try:
        if qtype in ("SELECT", "ASK"):
            ref = parse_select(ref_body)
            try:
                test = parse_select(test_body)
            except Exception as e:
                rec.update(status="error", side="test", detail="unparsable: " + repr(e))
                return rec
            ref_full = None
            if order_keys(q) and has_limit(q):
                full_body, _ = ref_cache.get(args.reference, strip_limit_offset(q),
                                             accept, args.timeout)
                ref_full = parse_select(full_body)
            status, info = compare_select(q, ref, test, ref_full)
        else:
            ref_g = parse_graph(ref_body, ref_ctype)
            try:
                test_g = parse_graph(test_body, test_ctype)
            except Exception as e:
                rec.update(status="error", side="test", detail="unparsable: " + repr(e))
                return rec
            status, info = compare_graph(ref_g, test_g)
    except Exception as e:
        rec.update(status="error", side="reference", detail="unparsable: " + repr(e))
        return rec

    rec["status"] = status
    rec.update(info)
    return rec


def summarize(records):
    by_q = {}
    for r in records:
        s = by_q.setdefault(r["query"], {"type": r["type"], **{k: 0 for k in STATUSES}})
        s[r["status"]] += 1
    rows = []
    for qnr in sorted(by_q):
        s = by_q[qnr]
        total = sum(s[k] for k in STATUSES)
        correct = s["match"] + s["match_modulo_ties"]
        rows.append({"query": qnr, "type": s["type"],
                     "informational": str(s["type"] in INFORMATIONAL_TYPES).lower(),
                     "total": total, **{k: s[k] for k in STATUSES},
                     "correct_pct": round(100.0 * correct / total, 1) if total else ""})
    return rows


def write_summary_txt(path, rows, records, meta):
    hdr = ["query", "type", "total", "correct_pct"] + STATUSES
    lines = ["== Correctness check (%s) ==" % meta.get("run_id", ""),
             "reference: %s" % meta.get("reference"),
             "test:      %s" % meta.get("test"),
             "(correct = match + match_modulo_ties; [i] = informational, see check-correctness.py)",
             ""]
    widths = [max(len(h), 9) for h in hdr]
    lines.append("  ".join(h.ljust(w) for h, w in zip(hdr, widths)))
    for r in rows:
        cells = [str(r["query"]) + (" [i]" if r["informational"] == "true" else ""),
                 r["type"], str(r["total"]), str(r["correct_pct"])] + [str(r[k]) for k in STATUSES]
        lines.append("  ".join(c.ljust(w) for c, w in zip(cells, widths)))
    graded = [r for r in rows if r["informational"] == "false"]
    tot = sum(r["total"] for r in graded)
    ok = sum(r["match"] + r["match_modulo_ties"] for r in graded)
    lines += ["", "Overall (non-informational): %d/%d correct (%.1f%%)"
              % (ok, tot, 100.0 * ok / tot if tot else 0.0)]
    worst = [r for r in records if SEVERITY[r["status"]] >= SEVERITY["content_mismatch"]
             or r["status"] == "error"]
    if worst:
        lines += ["", "First failing instances (full list in instances.jsonl):"]
        for r in worst[:10]:
            lines.append("  seq %-4d q%-2d %-16s ref=%s test=%s %s" % (
                r["seq"], r["query"], r["status"], r.get("ref_count", "-"),
                r.get("test_count", "-"),
                r.get("detail", "") if isinstance(r.get("detail"), str) else ""))
    text = "\n".join(lines) + "\n"
    with open(path, "w") as f:
        f.write(text)
    return text


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--queries", required=True, help="test-driver qualification run.log")
    ap.add_argument("--reference", required=True, help="reference SPARQL endpoint URL")
    ap.add_argument("--test", required=True, help="SPARQL endpoint URL under test")
    ap.add_argument("--out", required=True, help="output directory")
    ap.add_argument("--ref-cache", help="directory caching reference answers")
    ap.add_argument("--timeout", type=float, default=60.0, help="per-query timeout (s)")
    ap.add_argument("--meta", action="append", default=[], metavar="KEY=VALUE",
                    help="extra key/value pairs for meta.json")
    args = ap.parse_args()

    instances = parse_instances(args.queries)
    if not instances:
        sys.exit("No query instances found in %s" % args.queries)
    os.makedirs(args.out, exist_ok=True)
    ref_cache = RefCache(args.ref_cache)

    print("Checking %d query instances: test=%s reference=%s"
          % (len(instances), args.test, args.reference), file=sys.stderr)
    records = []
    with open(os.path.join(args.out, "instances.jsonl"), "w") as jf:
        for seq, (qnr, q) in enumerate(instances):
            rec = check_instance(seq, qnr, q, args, ref_cache)
            rec["query_text"] = q
            records.append(rec)
            jf.write(json.dumps(rec) + "\n")
            print("." if rec["status"] in ("match", "match_modulo_ties") else
                  "x" if rec["status"] != "error" else "E", end="", file=sys.stderr, flush=True)
    print(file=sys.stderr)

    rows = summarize(records)
    with open(os.path.join(args.out, "summary.csv"), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)

    meta = {"reference": args.reference, "test": args.test,
            "instances": len(records), "queries_log": args.queries,
            "timeout_s": args.timeout}
    for kv in args.meta:
        k, _, v = kv.partition("=")
        meta[k] = v
    with open(os.path.join(args.out, "meta.json"), "w") as f:
        json.dump(meta, f, indent=2)
    print(write_summary_txt(os.path.join(args.out, "summary.txt"), rows, records, meta))


if __name__ == "__main__":
    main()
