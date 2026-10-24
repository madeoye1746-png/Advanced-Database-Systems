"""Draws the NaijaMart ER diagram (crow's-foot style) as er_diagram.png.
Run: python make_er_diagram.py   (needs matplotlib)"""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle

# table -> (x, y, [(column, tag)]) ; tag: PK, FK, or ""
T = {
    "category": (0.3, 7.2, [("category_id", "PK"), ("name", ""), ("parent_category_id", "FK")]),
    "product": (0.3, 3.2, [("product_id", "PK"), ("sku", ""), ("name", ""), ("category_id", "FK"),
                           ("unit_price", ""), ("stock_qty", ""), ("is_active", "")]),
    "order_item": (4.6, 3.6, [("order_id", "PK,FK"), ("product_id", "PK,FK"), ("quantity", ""), ("unit_price", "")]),
    "orders": (8.9, 6.4, [("order_id", "PK"), ("customer_id", "FK"), ("order_date", ""), ("status", ""), ("total_amount", "")]),
    "customer": (13.6, 5.3, [("customer_id", "PK"), ("full_name", ""), ("email", ""), ("phone", ""),
                             ("city", ""), ("state", ""), ("created_at", "")]),
    "payment": (8.9, 3.2, [("payment_id", "PK"), ("order_id", "FK"), ("method", ""), ("amount", ""), ("status", ""), ("paid_at", "")]),
    "delivery": (13.6, 1.0, [("delivery_id", "PK"), ("order_id", "FK"), ("courier", ""), ("tracking_no", ""),
                             ("status", ""), ("shipped_at", ""), ("delivered_at", "")]),
    "stock_audit": (4.6, 0.2, [("audit_id", "PK"), ("product_id", "FK"), ("old_qty", ""), ("new_qty", ""), ("changed_at", "")]),
}
W, ROW, HEAD = 3.6, 0.36, 0.45

fig, ax = plt.subplots(figsize=(17, 10))
ax.set_xlim(0, 18); ax.set_ylim(-0.3, 10); ax.axis("off")
box = {}
for name, (x, y, cols) in T.items():
    h = HEAD + ROW * len(cols)
    top = y + h
    ax.add_patch(Rectangle((x, y), W, h, fc="#ffffff", ec="#1f3a5f", lw=1.6, zorder=2))
    ax.add_patch(Rectangle((x, top - HEAD), W, HEAD, fc="#1f3a5f", ec="#1f3a5f", zorder=3))
    ax.text(x + W / 2, top - HEAD / 2, name, color="white", ha="center", va="center", fontsize=12, weight="bold", zorder=4)
    for i, (c, tag) in enumerate(cols):
        cy = top - HEAD - ROW * (i + 0.5)
        ax.text(x + 0.12, cy, c, va="center", fontsize=10, zorder=4,
                weight="bold" if "PK" in tag else "normal")
        if tag:
            ax.text(x + W - 0.12, cy, tag, va="center", ha="right", fontsize=8.5, color="#b03a2e", zorder=4)
    box[name] = (x, y, W, h)

def mid(n, side):
    x, y, w, h = box[n]
    return {"l": (x, y + h / 2), "r": (x + w, y + h / 2), "t": (x + w / 2, y + h), "b": (x + w / 2, y)}[side]

def rel(a, sa, b, sb, one, many, label, dy1=0):
    (x1, y1), (x2, y2) = mid(a, sa), mid(b, sb)
    y1 += dy1
    ax.plot([x1, x2], [y1, y2], color="#555", lw=1.4, zorder=1)
    dx1 = 0.25 if sa in "rtb" else -0.25
    dx2 = 0.25 if sb in "rtb" else -0.25
    ax.text(x1 + dx1, y1 + (0.2 if sa in "lr" else (-0.25 if sa == "b" else 0.25)), one, fontsize=10, weight="bold", color="#0b6e4f", ha="center")
    ax.text(x2 + dx2, y2 + (0.2 if sb in "lr" else (-0.25 if sb == "b" else 0.25)), many, fontsize=10, weight="bold", color="#0b6e4f", ha="center")
    ax.text((x1 + x2) / 2, (y1 + y2) / 2 + 0.12, label, fontsize=8.5, style="italic", color="#444", ha="center",
            bbox=dict(fc="white", ec="none", pad=1), zorder=5)

rel("category", "b", "product", "t", "1", "N", "classifies")
rel("product", "r", "order_item", "l", "1", "N", "appears in")
rel("orders", "l", "order_item", "r", "1", "N", "contains")
rel("customer", "l", "orders", "r", "1", "N", "places")
rel("orders", "b", "payment", "t", "1", "0..1", "paid by")
rel("orders", "r", "delivery", "l", "1", "0..1", "delivered via", dy1=-0.7)
rel("product", "b", "stock_audit", "l", "1", "N", "audited in")

ax.text(8.75, 9.6, "NaijaMart Online - Entity Relationship Diagram (PostgreSQL 16)", ha="center", fontsize=15, weight="bold", color="#1f3a5f")
ax.text(8.75, 9.2, "PK = primary key   FK = foreign key   1 / N / 0..1 = cardinality   (category is self-referencing via parent_category_id)",
        ha="center", fontsize=9.5, color="#444")
plt.savefig("er_diagram.png", dpi=130, bbox_inches="tight", facecolor="white")
print("saved er_diagram.png")
