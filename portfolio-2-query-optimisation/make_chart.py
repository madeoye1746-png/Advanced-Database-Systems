"""Bar chart of query time before/after optimisation (log scale). Reads evidence/timing_summary.csv"""
import csv, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
rows = list(csv.DictReader(open("evidence/timing_summary.csv")))
labels = [r["query"].replace(" (", "\n(") for r in rows]
b = [float(r["before_ms"]) for r in rows]; a = [float(r["after_ms"]) for r in rows]
x = range(len(rows)); w = 0.38
fig, ax = plt.subplots(figsize=(10, 4.8))
ax.bar([i - w/2 for i in x], b, w, label="Before optimisation", color="#c0504d")
ax.bar([i + w/2 for i in x], a, w, label="After optimisation", color="#2e7d32")
for i, r in enumerate(rows):
    ax.text(i + w/2, a[i] * 1.15, r["speedup"], ha="center", fontsize=9, weight="bold")
ax.set_yscale("log"); ax.set_ylabel("Execution time (ms, log scale)")
ax.set_xticks(list(x)); ax.set_xticklabels(labels, fontsize=8.5)
ax.set_title("NaijaMart - query execution time before vs after optimisation (best of 3 runs)")
ax.legend(); ax.grid(axis="y", alpha=.3)
plt.tight_layout(); plt.savefig("performance_chart.png", dpi=130)
