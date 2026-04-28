"""
TTM Regression Analysis: Recipe Development Process
ООО «ПепсиКо Холдингс»
Author: P. Chervotkin | NUST MISiS | Applied Informatics, Systems Analytics

Goal: Quantify the impact of automation level and recipe complexity
      on Time-to-Market (TTM) for new product recipe development.

Usage:
    pip install pandas numpy matplotlib seaborn statsmodels
    python ttm_regression.py
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import statsmodels.api as sm
from statsmodels.stats.outliers_influence import variance_inflation_factor

# ── 1. Dataset (16 months: Jan 2023 – Apr 2024) ────────────────────────────────
data = {
    "month": [
        "2023-01", "2023-02", "2023-03", "2023-04",
        "2023-05", "2023-06", "2023-07", "2023-08",
        "2023-09", "2023-10", "2023-11", "2023-12",
        "2024-01", "2024-02", "2024-03", "2024-04",
    ],
    "period": list(range(1, 17)),
    # TTM — total days from TZ receipt to documentation release
    "ttm":           [45.7, 44.2, 44.8, 45.5, 42.2, 43.1, 41.5, 40.8,
                      40.2, 39.5, 38.9, 37.5, 36.1, 35.5, 34.8, 34.0],
    # X1: share of automated calculations in the process, %
    "auto_share":    [35.9, 42.1, 37.6, 35.0, 48.6, 45.2, 47.3, 50.1,
                      52.4, 54.0, 55.8, 57.1, 58.3, 59.2, 60.0, 60.0],
    # X2: number of ingredients in the recipe
    "ingredients":   [40, 36, 40, 37, 37, 38, 35, 33, 33, 32, 31, 29, 28, 27, 27, 27],
    # X3: number of manual regulatory checks
    "manual_checks": [7.2, 5.0, 6.9, 6.5, 5.3, 6.1, 5.8, 5.0,
                      4.5, 4.2, 3.8, 3.5, 3.2, 3.0, 2.8, 2.5],
}
df = pd.DataFrame(data)

# ── 2. Descriptive statistics ──────────────────────────────────────────────────
print("=" * 60)
print("1. DESCRIPTIVE STATISTICS")
print("=" * 60)
print(df[["ttm", "auto_share", "ingredients", "manual_checks"]].describe().round(3))

# ── 3. Time-series analysis ────────────────────────────────────────────────────
df["ttm_ma3"]  = df["ttm"].rolling(window=3, min_periods=1).mean()
chain_abs      = df["ttm"].diff()
chain_rate_pct = df["ttm"].pct_change() * 100

print("\n" + "=" * 60)
print("2. TIME SERIES DYNAMICS")
print("=" * 60)
print(f"  Mean absolute growth (chain): {chain_abs.mean():.2f} days/month")
print(f"  Mean growth rate    (chain): {chain_rate_pct.mean():.2f}%")

# Simple linear forecast
slope = np.polyfit(df["period"], df["ttm"], 1)
for month_ahead, label in zip([17, 18, 19], ["2024-05", "2024-06", "2024-07"]):
    forecast = np.polyval(slope, month_ahead)
    print(f"  Forecast {label}: {forecast:.1f} days")

# ── 4. OLS Multiple Regression ────────────────────────────────────────────────
X_raw = df[["auto_share", "ingredients", "manual_checks"]]
X     = sm.add_constant(X_raw)
y     = df["ttm"]

model = sm.OLS(y, X).fit()

print("\n" + "=" * 60)
print("3. OLS REGRESSION RESULTS")
print("=" * 60)
print(model.summary())

c = model.params
print("\nRegression equation:")
print(
    f"TTM = {c['const']:.3f} "
    f"+ ({c['auto_share']:.3f}) × Auto_Share "
    f"+ {c['ingredients']:.3f} × Ingredients "
    f"+ {c['manual_checks']:.3f} × Manual_Checks"
)
print(f"\nR² = {model.rsquared:.3f} | Adj. R² = {model.rsquared_adj:.3f}")

# ── 5. VIF — multicollinearity check ──────────────────────────────────────────
print("\n" + "=" * 60)
print("4. VARIANCE INFLATION FACTORS")
print("=" * 60)
for i, col in enumerate(X_raw.columns):
    vif = variance_inflation_factor(X_raw.values, i)
    flag = "⚠  possible multicollinearity" if vif > 5 else "✓ OK"
    print(f"  {col:20s}: VIF = {vif:.2f}  {flag}")

# ── 6. Scenario forecasting ───────────────────────────────────────────────────
scenarios = {
    "Базовый  (auto=45%, ingr=28, mc=3.5)": [45.0, 28, 3.5],
    "Целевой  (auto=50%, ingr=30, mc=2.5)": [50.0, 30, 2.5],
    "Оптимал. (auto=55%, ingr=32, mc=2.0)": [55.0, 32, 2.0],
}
print("\n" + "=" * 60)
print("5. SCENARIO FORECAST")
print("=" * 60)
for name, vals in scenarios.items():
    pred = model.predict([1] + vals)[0]
    print(f"  {name} → TTM = {pred:.1f} days")

# ── 7. Visualisations ─────────────────────────────────────────────────────────
plt.style.use("seaborn-v0_8-whitegrid")
fig, axes = plt.subplots(2, 2, figsize=(14, 10))
fig.suptitle(
    "TTM Analysis: Recipe Development Process | PepsiCo Holdings",
    fontsize=13, fontweight="bold"
)

# 7.1 TTM trend
ax = axes[0, 0]
ax.plot(df["period"], df["ttm"],     "o-",  color="#2196F3", lw=2, label="Фактический TTM")
ax.plot(df["period"], df["ttm_ma3"], "s--", color="#FF9800", lw=1.5, label="Скользящая средняя (3 мес.)")
# Forecast
periods_f = [17, 18, 19]
forecast_vals = [np.polyval(slope, p) for p in periods_f]
ax.plot(periods_f, forecast_vals, "^:", color="#4CAF50", lw=1.5, label="Прогноз")
ax.set_title("Динамика Time-to-Market (TTM)")
ax.set_ylabel("Дней")
ax.legend(fontsize=8)
ax.set_xticks(df["period"])
ax.set_xticklabels(df["month"], rotation=45, fontsize=7)

# 7.2 Chain increments
ax = axes[0, 1]
colors = ["#F44336" if (x if not np.isnan(x) else 0) > 0 else "#4CAF50"
          for x in chain_abs.fillna(0)]
ax.bar(df["period"], chain_abs, color=colors, edgecolor="white")
ax.axhline(0, color="black", lw=0.8)
ax.set_title("Цепные абсолютные приросты TTM")
ax.set_ylabel("Прирост, дней")

# 7.3 Correlation heatmap
ax = axes[1, 0]
corr = df[["ttm", "auto_share", "ingredients", "manual_checks"]].corr()
sns.heatmap(
    corr, annot=True, fmt=".2f", cmap="RdBu_r",
    center=0, ax=ax, square=True, linewidths=0.5
)
ax.set_title("Корреляционная матрица факторов")

# 7.4 Actual vs Fitted
ax = axes[1, 1]
fitted = model.fittedvalues
ax.scatter(y, fitted, color="#9C27B0", alpha=0.8, s=60, edgecolors="white")
lims = [min(y.min(), fitted.min()) - 1, max(y.max(), fitted.max()) + 1]
ax.plot(lims, lims, "k--", lw=1)
ax.set_title(f"Фактические vs Расчётные значения (R² = {model.rsquared:.3f})")
ax.set_xlabel("Факт. TTM, дней")
ax.set_ylabel("Расч. TTM, дней")

plt.tight_layout()
output_path = "ttm_analysis.png"
plt.savefig(output_path, dpi=150, bbox_inches="tight")
print(f"\nВизуализация сохранена: {output_path}")
plt.show()
