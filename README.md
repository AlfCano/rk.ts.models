# rk.ts.models: Expert Time Series Modeling, ARIMA/xreg, and VAR/Granger for RKWard

![Version](https://img.shields.io/badge/Version-0.0.1-blue.svg)
[![License: GPL v3](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
![RKWard](https://img.shields.io/badge/Platform-RKWard-green)
[![R Linter](https://github.com/AlfCano/rk.ts.models/actions/workflows/lintr.yml/badge.svg)](https://github.com/AlfCano/rk.ts.models/actions/workflows/lintr.yml)
![AI Gemini](https://img.shields.io/badge/AI-Gemini-4285F4?logo=googlegemini&logoColor=white)

**A Zero-Code GUI Wrapper for `forecast`, `tsoutliers`, and `vars` bringing SPSS-Parity Forecasting & Temporal Causal Modeling to RKWard**

`rk.ts.models` is the core modeling engine of the RKWard Time Series & Forecasting suite (seamlessly building upon [`rk.ts.prep`](https://github.com/AlfCano/rk.ts.prep) and [`rk.forecast`](https://github.com/AlfCano/rk.forecast)). Designed for analysts migrating from SPSS Forecasting or practicing modern econometric workflows, this plugin offers an intuitive, point-and-click interface for Expert Modeling (Auto-ARIMA vs. ETS + Ensembles), Outlier Detection, Dynamic Regression (`xreg`), Model Reuse, and Multivariate Causal Analysis (VAR & Granger Causality)—without writing a single line of R code.

---

## 🌟 Key Features

*   **Expert Modeler (Auto-ARIMA, ETS & Ensembles):** Automatically pits `auto.arima()` against `ets()` and selects the winner by lowest **RMSE**, or averages both into a robust **Ensemble forecast**. Includes automatic Box-Cox variance stabilization and residual Ljung-Box diagnostics.
*   **SPSS-Style Outlier Detection:** Choose between fast automated cleaning (`forecast::tsclean`) or full Chen & Liu iterative outlier detection (`tsoutliers::tso`), identifying Additive Outliers (**AO**), Level Shifts (**LS**), and Temporary Changes (**TC**).
*   **Custom ARIMA & Dynamic Regression (`xreg`):** Manually specify `ARIMA(p,d,q)(P,D,Q)[m]` orders or include external numeric regressors (prices, promotions, macro indicators) with a full coefficient table ($z$-values, $p$-values, significance stars) and support for future predictor data frames (`newxreg`).
*   **Apply Saved Models:** Replicates SPSS *Apply Time Series Models*—score new data using saved `Arima` or `ets` models while preserving existing parameters or re-estimating parameters using the saved structure.
*   **Temporal Causal Modeling (VAR & Granger):** Build multivariate Vector Autoregressive (`vars`) systems with automatic lag selection (`AIC`, `SC/BIC`, `HQ`, `FPE`), automated **Granger Causality tables** across all variables, Portmanteau residual checks, and multi-panel **Orthogonal Impulse Response Functions (IRF)** with 95% Bootstrap confidence intervals.
*   **Multilingual Ready:** Prepared for English, Spanish, French, German, and Portuguese (Brazil).

---

## What's New in Version 0.0.1

*   **Initial Release:** Introduces 4 comprehensive modeling tools nested cleanly under `Analysis > Time Series > Time Series Models`.
*   **Smart Auto-Focus & Safe Evaluation:** Dual `ts` / `data.frame` Auto-Focus GUI scripts, live `ggplot2` and `vars` previews, pixel/DPI control over `rk.graph.on()`, and clean `call` handling for `Arima` and `VAR` bootstrap routines.

---

## ⚙️ Prerequisites

You must have [RKWard](https://rkward.kde.org/) installed along with the following R packages:

```R
install.packages(c("forecast", "ggplot2", "vars", "tsoutliers"))
```

---

## 🚀 Installation

You can install this plugin directly from R-Universe or GitHub inside your RKWard console:

```R
# From R-Universe (Recommended)
install.packages('rk.ts.models', repos = c('https://alfcano.r-universe.dev', 'https://cloud.r-project.org'))

# Or directly from GitHub
library("remotes")
install_github("AlfCano/rk.ts.models")
```

Once installed, restart RKWard to ensure the new menu entries under **Analysis > Time Series > Time Series Models** appear correctly.

---

## 🛠️ Usage Workflow (The 4 Modules)

This plugin adds four complete modeling dialogs under **Analysis > Time Series > Time Series Models**:

1. **Expert Modeler (Auto-ARIMA, ETS, Ensemble):** Automatic model selection, Box-Cox stabilization, outlier adjustment, and residual Ljung-Box diagnostics.
2. **Custom ARIMA & Dynamic Regression (xreg):** Full Box-Jenkins `(p,d,q)(P,D,Q)` control and external predictor regressions with `newxreg` forecasting.
3. **Apply Saved Model:** Reuse previously saved `Arima` or `ets` objects on updated series with or without parameter re-estimation.
4. **Temporal Causal Modeling (VAR & Granger):** Multivariate lag optimization, Granger causality testing, residual autocorrelation checks, and Impulse Response Functions.

---

## 📊 Complete Practical Case Studies

### Case Study 1: Expert Modeler (Auto-ARIMA vs. ETS)
*Goal: Let the algorithm automatically select the best model for our cleaned `ts_clean` series (created in `rk.ts.prep` from `AirPassengers`).*
1. Go to **Analysis > Time Series > Time Series Models > 1. Expert Modeler (Auto-ARIMA, ETS, Ensemble)**.
2. Select `ts_clean` as your **Time Series Object (ts)**.
3. Leave Candidate Models on **"All (Compare Auto-ARIMA vs ETS - Pick Best by RMSE)"**, Forecast Horizon `12`, and check **Save Winning Model Object as** (`expert_model`).
4. Click **Submit**.
   *👉 Look at **Model Comparison**: Both `ARIMA(2,1,1)(0,1,0)[12]` and `ETS(M,Ad,M)` achieve an **RMSE of ~11** and **MAPE of ~2.7–2.8%**, giving you an immediate head-to-head accuracy benchmark alongside the Ljung-Box residual check.*

---

### Case Study 2: Custom Box-Jenkins ARIMA & Dynamic Regression (`xreg`)
*Part A — Classic Box-Jenkins Verification:*
1. Go to **2. Custom ARIMA & Dynamic Regression (xreg)**.
2. In **1. Data & Regressors**, keep `Time Series Object (ts)` and select `ts_clean`.
3. In **2. ARIMA Order & Horizon**, enter the Airline Model orders diagnosed in `rk.ts.prep`: `p = 0, d = 1, q = 1` and seasonal `P = 0, D = 1, Q = 1`. Check **Apply Auto Box-Cox Transformation**.
4. Click **Submit** to verify `ma1` and `sma1` significance (`p < 0.001 ***`) and compare RMSE/MAPE against the Expert Modeler. *(Note: AICc with Box-Cox is on a transformed scale; compare models across transformations using RMSE/MAPE).*

*Part B — Dynamic Regression with External Predictors (`xreg`):*
1. In the **R Console**, simulate 48 months of retail sales boosted every December (`promo = 1`) plus 12 future months:
   ```R
   set.seed(123)
   df_sales <- data.frame(
     sales = 100 + 2 * (1:48) + 15 * sin(2 * pi * (1:48) / 12) + c(rep(0, 11), 25)[((1:48) - 1) %% 12 + 1] + rnorm(48, 0, 4),
     promo = rep(c(rep(0, 11), 1), 4)
   )
   df_future <- data.frame(promo = c(rep(0, 11), 1))
   ```
2. Open **2. Custom ARIMA & Dynamic Regression (xreg)** and switch **Input Data Source** to **Data Frame**.
3. Select `df_sales`, set `sales` as Target (Y), `promo` as External Regressor (`xreg`), Frequency `Monthly (12)`.
4. On Tab **2. ARIMA Order & Horizon**, select `df_future` as **Future Regressors Data Frame** and set orders `(1,1,0)(0,0,0)`.
5. Click **Submit**.
   *👉 The **Model Parameters** table quantifies the exact dollar/unit lift of `promo` (`Estimate ≈ +25`, `***`), and the forecast chart projects the next 12 months including the December promotional spike.*

---

### Case Study 3: Apply Saved Model (Operational Refresh)
*Goal: Score updated data without re-estimating model coefficients (SPSS Apply Mode).*
1. Go to **3. Apply Saved Model**.
2. Select `expert_model` (saved in Case Study 1) as the **Saved Model Object**.
3. Choose **Apply Model to New Time Series (ts)**, select an updated series (e.g., `AirPassengers` loaded via `data(AirPassengers)`), and keep **"Keep Saved Parameters (No re-estimation)"**.
4. Click **Submit** to generate updated forecasts and accuracy metrics using the exact historical parameters.

---

### Case Study 4: Temporal Causal Modeling (VAR & Granger Causality)
*Goal: Model bidirectional macroeconomic causality between Employment (`e`), Productivity (`prod`), Real Wages (`rw`), and Unemployment (`U`).*
1. In the **R Console**, load the classic Canadian macroeconomic dataset:
   ```R
   data(Canada, package = "vars")
   ```
2. Go to **Analysis > Time Series > Time Series Models > 4. Temporal Causal Modeling (VAR & Granger)**.
3. Switch **Input Data Format** to **Multivariate Time Series (mts)** and select `Canada`.
4. Under **2. VAR & Causality**, keep **Auto-detect Optimal Lag (AIC)**, Forecast Horizon `12`, and check both **Compute Granger Causality Tests** and **Plot Impulse Response Functions (IRF)**.
5. Click **Submit**.

**What to look for in the HTML Output:**
*   **Optimal Lag Selection (`VARselect`):** Identifies `p = 3` under AIC/FPE.
*   **Granger Causality Tests:** Every variable shows $p < 0.05$ (`e`: $p = 0.0001$, `prod`: $p = 0.0027$, `rw`: $p = 0.0257$, `U`: $p = 0.0330$), revealing statistically significant system-wide causal feedback.
*   **Residual Serial Correlation:** Portmanteau test yields $p = 0.97$ (*No residual autocorrelation*), confirming an adequate dynamic fit.
*   **Impulse Response Functions (95% Bootstrap CI):** Inspecting the shock from `prod` clearly shows employment (`e`) rising significantly above zero while unemployment (`U`) drops significantly below zero over the 12-quarter horizon.

---

## 🗣️ Communicating with Numbers (Translating Output to Business)

> *"Our Expert Modeler benchmarked competing statistical families and achieved a 2.7% MAPE on historical demand. Incorporating promotional indicators via Dynamic Regression isolated an exact +25 unit lift per campaign (`p < 0.001`), while multivariate VAR causal modeling confirmed that productivity gains significantly drive down unemployment and lift employment over a 3-year horizon. Saved models can now be re-applied to incoming monthly data with a single click."*

---

## 🌍 Internationalization (i18n)

The graphical interface automatically adapts to your RKWard language settings. Currently supported languages:
*   🇺🇸 English (Default)
*   🇪🇸 Spanish (Español)
*   🇫🇷 French (Français)
*   🇩🇪 German (Deutsch)
*   🇧🇷 Portuguese (Português do Brasil)

---

## 📝 License and Author

**Author:** Alfonso Cano ([@AlfCano](https://github.com/AlfCano))  
**Email:** alfonso.cano@correo.buap.mx  
*   **Assisted by:** Gemini, a large language model from Google.
*   **License:** GPL (>= 3)

This project is licensed under the **GPL (>= 3)** License.
