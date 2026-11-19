local({
  # =========================================================================================
  # 1. Setup and Metadata
  # =========================================================================================
  require(rkwarddev)
  rkwarddev.required("0.10-3")

  plugin_name <- "rk.ts.models"

  package_about <- rk.XML.about(
    name = plugin_name,
    author = person(
      given = "Alfonso",
      family = "Cano",
      email = "alfonso.cano@correo.buap.mx",
      role = c("aut", "cre")
    ),
    about = list(
      desc = "SPSS-parity Time Series Modeling for RKWard: Expert Modeler (Auto-ARIMA, ETS, Ensemble, Outliers), Custom ARIMA with Dynamic Regression (xreg), Apply Saved Models, and VAR/Granger Causality.",
      version = "0.0.1",
      url = "https://github.com/AlfCano/rk.ts.models",
      license = "GPL (>= 3)"
    )
  )

  dependencies_node <- rk.XML.dependencies(
    dependencies = list(R.min = "4.0.0"),
    package = list(
      c(name = "forecast"),
      c(name = "ggplot2"),
      c(name = "vars"),
      c(name = "tsoutliers")
    )
  )

  # MISMA JERARQUÍA BASE QUE rk.forecast Y rk.ts.prep (Regla de Oro #2)
  h_models <- list("analysis", "time_series", "Time Series Models")

  # Global JavaScript Helper Functions (Regla de Oro #8)
  js_helpers <- "
    function cleanStr(val) {
        if(!val) return '';
        return val.replace(/'/g, \"\\\\'\").replace(/\"/g, '\\\\\"');
    }

    function parseVar(fullPath) {
        if (!fullPath) return '';
        var raw_col = '';
        if (fullPath.indexOf('[[') > -1) {
            var parts = fullPath.split('[[');
            var inner = parts[1].replace(']]', '');
            raw_col = inner.replace(/[\"']/g, '');
        } else if (fullPath.indexOf('$') > -1) {
            raw_col = fullPath.split('$')[1];
        } else {
            raw_col = fullPath;
        }
        return raw_col;
    }
  "

  # =========================================================================================
  # 2. MODULE 1 (MAIN): 1. Expert Modeler (Auto-ARIMA, ETS & Ensemble)
  # =========================================================================================

  # --- UI Elements ---
  exp_vs <- rk.XML.varselector(id.name = "exp_vs")
  exp_ts <- rk.XML.varslot("Time Series Object (ts)", source = "exp_vs", classes = "ts", required = TRUE, id.name = "exp_ts")

  exp_scope <- rk.XML.radio("Candidate Models (Expert Scope)", options = list(
    "All (Compare Auto-ARIMA vs ETS - Pick Best by RMSE)" = list(val = "both", chk = TRUE),
    "Auto-ARIMA Only" = list(val = "arima"),
    "Exponential Smoothing (ETS) Only" = list(val = "ets"),
    "Ensemble Forecast (Average of Auto-ARIMA + ETS)" = list(val = "ensemble")
  ), id.name = "exp_scope")

  exp_h <- rk.XML.spinbox("Forecast Horizon (h)", min = 1, max = 240, initial = 12, real = FALSE, id.name = "exp_h")
  exp_bc <- rk.XML.cbox("Auto Box-Cox Transformation (Stabilize variance, lambda = 'auto')", value = "1", chk = FALSE, id.name = "exp_bc")

  exp_outliers <- rk.XML.dropdown("Outlier Detection & Adjustment", options = list(
    "None (Keep original series)" = list(val = "none", chk = TRUE),
    "Fast Automatic Cleaning (forecast::tsclean)" = list(val = "fast"),
    "SPSS-Style Iterative Detection: AO/LS/TC (tsoutliers::tso)" = list(val = "tso")
  ), id.name = "exp_outliers")

  exp_res_diag <- rk.XML.cbox("Run Residual Diagnostics (Ljung-Box Test on residuals)", value = "1", chk = TRUE, id.name = "exp_res_diag")

  frm_exp_opts <- rk.XML.frame(exp_scope, exp_h, exp_bc, exp_outliers, exp_res_diag, label = "Expert Modeler Configuration")

  # Plot Options
  exp_theme <- rk.XML.dropdown("Plot Theme (ggplot2)", options = list(
    "Minimal (Clean business look)" = list(val = "minimal", chk = TRUE),
    "Classic (Scientific)" = list(val = "classic"),
    "Black & White (Grid)" = list(val = "bw")
  ), id.name = "exp_theme")
  exp_plot_main <- rk.XML.input("Main Title (Leave empty for default)", id.name = "exp_plot_main")
  exp_plot_xlab <- rk.XML.input("X-Axis Label (Leave empty for default)", id.name = "exp_plot_xlab")
  exp_plot_ylab <- rk.XML.input("Y-Axis Label (Leave empty for default)", id.name = "exp_plot_ylab")
  frm_exp_plot <- rk.XML.frame(exp_theme, exp_plot_main, exp_plot_xlab, exp_plot_ylab, label = "Plot Customization")

  # Output Options
  exp_save_fc <- rk.XML.saveobj("Save Forecast Object as", initial = "expert_forecast", chk = TRUE, id.name = "exp_save_fc")
  exp_save_mod <- rk.XML.saveobj("Save Winning Model Object as (For Module 3)", initial = "expert_model", chk = FALSE, id.name = "exp_save_mod")

  exp_plot_w <- rk.XML.spinbox("HTML Plot Width (pixels)", min = 100, max = 5000, initial = 800, real = FALSE, id.name = "exp_plot_w")
  exp_plot_h <- rk.XML.spinbox("HTML Plot Height (pixels)", min = 100, max = 5000, initial = 600, real = FALSE, id.name = "exp_plot_h")
  exp_plot_res <- rk.XML.spinbox("Resolution (DPI)", min = 72, max = 600, initial = 120, real = FALSE, id.name = "exp_plot_res")
  frm_exp_graph <- rk.XML.frame(rk.XML.row(exp_plot_w, exp_plot_h, exp_plot_res), label = "HTML Graphics Size & Resolution")
  exp_save_plot <- rk.XML.saveobj("Save Plot (ggplot2) as", initial = "expert_plot", chk = FALSE, id.name = "exp_save_plot")

  exp_preview <- rk.XML.preview(label = "Preview Expert Forecast Plot")

  # --- Logic & Layout ---
  logic_exp <- rk.XML.logic()

  tab_exp <- rk.XML.tabbook(tabs = list(
    "Data & Model" = rk.XML.col(exp_ts, frm_exp_opts, rk.XML.stretch()),
    "Plot Options" = rk.XML.col(frm_exp_plot, rk.XML.stretch()),
    "Output" = rk.XML.col(
      rk.XML.frame(exp_save_fc, exp_save_mod, label = "Save Objects to Workspace"),
      frm_exp_graph,
      rk.XML.frame(exp_save_plot, label = "Save Plot Object"),
      rk.XML.stretch()
    )
  ))

  dialog_exp <- rk.XML.dialog(
    rk.XML.row(
      exp_vs,
      rk.XML.col(tab_exp, exp_preview)
    ),
    label = "1. Expert Modeler (Auto-ARIMA, ETS, Ensemble)"
  )

  # --- JavaScript ---
  js_calc_exp <- "
    var ts_obj = getValue('exp_ts');
    var scope = getValue('exp_scope');
    var h = getValue('exp_h');
    var do_bc = getValue('exp_bc') === '1';
    var out_mode = getValue('exp_outliers');
    var do_diag = getValue('exp_res_diag') === '1';

    var theme = getValue('exp_theme');
    var main_tit = cleanStr(getValue('exp_plot_main'));
    var x_tit = cleanStr(getValue('exp_plot_xlab'));
    var y_tit = cleanStr(getValue('exp_plot_ylab'));

    echo('x_ts <- ' + ts_obj + '\\n');
    echo('if (anyNA(x_ts)) stop(\"Series contains NAs. Please impute missing values first using rk.ts.prep.\")\\n\\n');

    // 1. Outliers
    echo('out_table <- data.frame()\\n');
    if (out_mode === 'none') {
        echo('x_clean <- x_ts\\n');
    } else if (out_mode === 'fast') {
        echo('out_info <- forecast::tsoutliers(x_ts)\\n');
        echo('x_clean <- forecast::tsclean(x_ts)\\n');
        echo('if (length(out_info$index) > 0) {\\n');
        echo('  out_table <- data.frame(Index = out_info$index, Original = round(as.numeric(x_ts[out_info$index]), 4), Replacement = round(as.numeric(out_info$replacements), 4))\\n');
        echo('}\\n');
    } else if (out_mode === 'tso') {
        echo('if (!requireNamespace(\"tsoutliers\", quietly = TRUE)) stop(\"Package tsoutliers is required for Chen & Liu (AO/LS/TC) detection.\")\\n');
        echo('tso_res <- tsoutliers::tso(x_ts)\\n');
        echo('x_clean <- tso_res$yadj\\n');
        echo('if (nrow(tso_res$outliers) > 0) {\\n');
        echo('  out_table <- as.data.frame(tso_res$outliers)\\n');
        echo('}\\n');
    }
    echo('\\n');

    // 2. Box-Cox
    if (do_bc) {
        echo('if (any(x_clean <= 0, na.rm = TRUE)) stop(\"Box-Cox transformation requires strictly positive values (> 0).\")\\n');
        echo('lam_val <- \"auto\"\\n');
    } else {
        echo('lam_val <- NULL\\n');
    }
    echo('\\n');

    // 3. Fit Candidate Models
    echo('comp_table <- data.frame()\\n');
    if (scope === 'arima') {
        echo('expert_model <- forecast::auto.arima(x_clean, lambda = lam_val)\\n');
        echo('expert_forecast <- forecast::forecast(expert_model, h = ' + h + ')\\n');
        echo('acc_m <- forecast::accuracy(expert_model)\\n');
        echo('comp_table <- data.frame(Model = paste(\"Auto-ARIMA:\", as.character(expert_model)), RMSE = round(acc_m[1, \"RMSE\"], 4), MAE = round(acc_m[1, \"MAE\"], 4), MAPE = round(acc_m[1, \"MAPE\"], 4), AICc = round(expert_model$aicc, 2), Selected = \"Yes\")\\n');
    } else if (scope === 'ets') {
        echo('expert_model <- forecast::ets(x_clean, lambda = lam_val)\\n');
        echo('expert_forecast <- forecast::forecast(expert_model, h = ' + h + ')\\n');
        echo('acc_m <- forecast::accuracy(expert_model)\\n');
        echo('comp_table <- data.frame(Model = paste(\"ETS:\", expert_model$method), RMSE = round(acc_m[1, \"RMSE\"], 4), MAE = round(acc_m[1, \"MAE\"], 4), MAPE = round(acc_m[1, \"MAPE\"], 4), AICc = round(expert_model$aicc, 2), Selected = \"Yes\")\\n');
    } else if (scope === 'both') {
        echo('mod_arima <- forecast::auto.arima(x_clean, lambda = lam_val)\\n');
        echo('mod_ets   <- forecast::ets(x_clean, lambda = lam_val)\\n');
        echo('acc_a <- forecast::accuracy(mod_arima)\\n');
        echo('acc_e <- forecast::accuracy(mod_ets)\\n');
        echo('win_arima <- acc_a[1, \"RMSE\"] <= acc_e[1, \"RMSE\"]\\n');
        echo('if (win_arima) { expert_model <- mod_arima } else { expert_model <- mod_ets }\\n');
        echo('expert_forecast <- forecast::forecast(expert_model, h = ' + h + ')\\n');
        echo('comp_table <- data.frame(\\n');
        echo('  Model = c(paste(\"Auto-ARIMA:\", as.character(mod_arima)), paste(\"ETS:\", mod_ets$method)),\\n');
        echo('  RMSE  = round(c(acc_a[1, \"RMSE\"], acc_e[1, \"RMSE\"]), 4),\\n');
        echo('  MAE   = round(c(acc_a[1, \"MAE\"], acc_e[1, \"MAE\"]), 4),\\n');
        echo('  MAPE  = round(c(acc_a[1, \"MAPE\"], acc_e[1, \"MAPE\"]), 4),\\n');
        echo('  AICc  = round(c(mod_arima$aicc, mod_ets$aicc), 2),\\n');
        echo('  Selected = c(ifelse(win_arima, \"Winner (Lowest RMSE)\", \"No\"), ifelse(!win_arima, \"Winner (Lowest RMSE)\", \"No\"))\\n');
        echo(')\\n');
    } else if (scope === 'ensemble') {
        echo('mod_arima <- forecast::auto.arima(x_clean, lambda = lam_val)\\n');
        echo('mod_ets   <- forecast::ets(x_clean, lambda = lam_val)\\n');
        echo('fc_a <- forecast::forecast(mod_arima, h = ' + h + ')\\n');
        echo('fc_e <- forecast::forecast(mod_ets, h = ' + h + ')\\n');
        echo('fc_ens <- fc_a\\n');
        echo('fc_ens$method <- \"Ensemble (Auto-ARIMA + ETS)\"\\n');
        echo('fc_ens$mean   <- (fc_a$mean + fc_e$mean) / 2\\n');
        echo('fc_ens$lower  <- (fc_a$lower + fc_e$lower) / 2\\n');
        echo('fc_ens$upper  <- (fc_a$upper + fc_e$upper) / 2\\n');
        echo('fc_ens$fitted <- (stats::fitted(mod_arima) + stats::fitted(mod_ets)) / 2\\n');
        echo('fc_ens$residuals <- x_clean - fc_ens$fitted\\n');
        echo('expert_forecast <- fc_ens\\n');
        echo('expert_model <- list(arima = mod_arima, ets = mod_ets, method = \"Ensemble\")\\n');
        echo('acc_a <- forecast::accuracy(mod_arima)\\n');
        echo('acc_e <- forecast::accuracy(mod_ets)\\n');
        echo('acc_ens <- forecast::accuracy(expert_forecast)\\n');
        echo('comp_table <- data.frame(\\n');
        echo('  Model = c(paste(\"Auto-ARIMA:\", as.character(mod_arima)), paste(\"ETS:\", mod_ets$method), \"Ensemble (Average)\"),\\n');
        echo('  RMSE  = round(c(acc_a[1, \"RMSE\"], acc_e[1, \"RMSE\"], acc_ens[1, \"RMSE\"]), 4),\\n');
        echo('  MAE   = round(c(acc_a[1, \"MAE\"], acc_e[1, \"MAE\"], acc_ens[1, \"MAE\"]), 4),\\n');
        echo('  MAPE  = round(c(acc_a[1, \"MAPE\"], acc_e[1, \"MAPE\"], acc_ens[1, \"MAPE\"]), 4),\\n');
        echo('  Selected = c(\"Component\", \"Component\", \"Active Ensemble\")\\n');
        echo(')\\n');
    }
    echo('\\n');

    // 4. Residual Diagnostics
    echo('res_diag_tbl <- data.frame()\\n');
    if (do_diag) {
        echo('res_vec <- stats::na.omit(stats::residuals(expert_forecast))\\n');
        echo('n_r <- length(res_vec); m_r <- stats::frequency(x_clean)\\n');
        echo('lb_lag <- max(1, if (m_r > 1) min(2 * m_r, floor(n_r / 5)) else min(10, floor(n_r / 5)))\\n');
        echo('fit_df <- if (inherits(expert_model, \"Arima\")) length(stats::coef(expert_model)) else 0\\n');
        echo('if (lb_lag <= fit_df) lb_lag <- fit_df + 1\\n');
        echo('tryCatch({\\n');
        echo('  lb <- stats::Box.test(res_vec, lag = lb_lag, type = \"Ljung-Box\", fitdf = fit_df)\\n');
        echo('  lb_msg <- ifelse(lb$p.value >= 0.05, \"White Noise (Adequate Fit)\", \"Residual Autocorrelation Remains\")\\n');
        echo('  res_diag_tbl <- data.frame(Test = \"Ljung-Box (Residuals)\", Statistic = round(as.numeric(lb$statistic), 4), Lag = lb_lag, P_Value = round(lb$p.value, 4), Conclusion = lb_msg)\\n');
        echo('}, error = function(e) {})\\n');
    }
    echo('\\n');

    // 5. ggplot
    var title_str = (main_tit !== '') ? main_tit : 'Expert Modeler Forecast: ' + ts_obj;
    echo('p <- ggplot2::autoplot(expert_forecast) + ggplot2::theme_' + theme + '() +\\n');
    echo('     ggplot2::labs(title = \"' + title_str + '\"');
    if (x_tit !== '') echo(', x = \"' + x_tit + '\"');
    if (y_tit !== '') echo(', y = \"' + y_tit + '\"');
    echo(') + ggplot2::theme(legend.position = \"bottom\")\\n');
  "

  js_print_exp <- "
    var w = getValue('exp_plot_w');
    var h = getValue('exp_plot_h');
    var res = getValue('exp_plot_res');

    if (typeof is_preview !== 'undefined' && is_preview) {
        echo('print(p)\\n');
    }

    if (typeof is_preview === 'undefined' || !is_preview) {
        echo('rk.header(\"1. Expert Modeler Results\")\\n');

        echo('rk.graph.on(width = ' + w + ', height = ' + h + ', res = ' + res + ')\\n');
        echo('print(p)\\n');
        echo('rk.graph.off()\\n\\n');

        echo('rk.header(\"Model Comparison & Accuracy Metrics (In-Sample)\", level = 3)\\n');
        echo('rk.print(comp_table)\\n');

        echo('if (nrow(out_table) > 0) {\\n');
        echo('  rk.header(\"Detected & Adjusted Outliers\", level = 3)\\n');
        echo('  rk.print(out_table)\\n');
        echo('}\\n');

        echo('if (nrow(res_diag_tbl) > 0) {\\n');
        echo('  rk.header(\"Residual Diagnostics\", level = 3)\\n');
        echo('  rk.print(res_diag_tbl)\\n');
        echo('}\\n');

        echo('rk.header(\"Forecasted Values\", level = 3)\\n');
        echo('rk.print(as.data.frame(expert_forecast))\\n');

        if (getValue('exp_save_fc.active') || getValue('exp_save_mod.active') || getValue('exp_save_plot.active')) {
            echo('rk.print(\"<hr>\")\\n');
        }
        if (getValue('exp_save_fc.active')) {
            echo('rk.print(paste0(\"<b>Forecast object saved as: </b><code>\", \"' + getValue('exp_save_fc') + '\", \"</code><br>\"))\\n');
        }
        if (getValue('exp_save_mod.active')) {
            echo('rk.print(paste0(\"<b>Model object saved as: </b><code>\", \"' + getValue('exp_save_mod') + '\", \"</code><br>\"))\\n');
        }
        if (getValue('exp_save_plot.active')) {
            echo('p$plot_env <- emptyenv()\\n');
            echo('expert_plot <- p\\n');
            echo('rk.print(paste0(\"<b>Plot object (ggplot2) saved as: </b><code>\", \"' + getValue('exp_save_plot') + '\", \"</code>\"))\\n');
        }
    }
  "

  # =========================================================================================
  # 3. MODULE 2: 2. Custom ARIMA & Dynamic Regression (xreg)
  # =========================================================================================

  # --- UI Elements ---
  cust_vs <- rk.XML.varselector(id.name = "cust_vs")

  cust_src_mode <- rk.XML.radio("Input Data Source", options = list(
    "Time Series Object (ts - Univariate ARIMA)" = list(val = "ts", chk = TRUE),
    "Data Frame (Dynamic Regression with External Regressors xreg)" = list(val = "df")
  ), id.name = "cust_src_mode")

  # Mode TS
  cust_ts <- rk.XML.varslot("Time Series Object (ts)", source = "cust_vs", classes = "ts", required = FALSE, id.name = "cust_ts")
  frm_cust_ts <- rk.XML.frame(cust_ts, label = "Univariate Series Input", id.name = "frm_cust_ts")

  # Mode DF (with xreg)
  cust_df <- rk.XML.varslot("Training Data Frame", source = "cust_vs", classes = "data.frame", required = FALSE, id.name = "cust_df")
  cust_y <- rk.XML.varslot("Target Variable (Y, Numeric)", source = "cust_vs", classes = c("numeric", "integer"), required = FALSE, id.name = "cust_y")
  cust_xreg <- rk.XML.varslot("External Regressors (xreg - Optional, Numeric)", source = "cust_vs", classes = c("numeric", "integer"), multi = TRUE, required = FALSE, id.name = "cust_xreg")

  cust_freq <- rk.XML.dropdown("Frequency", options = list(
    "Monthly (12)" = list(val = "12", chk = TRUE),
    "Quarterly (4)" = list(val = "4"),
    "Yearly (1)" = list(val = "1"),
    "Weekly (52)" = list(val = "52"),
    "Daily - Business (5)" = list(val = "5"),
    "Daily - Full (7)" = list(val = "7")
  ), id.name = "cust_freq")
  cust_yr <- rk.XML.spinbox("Start Year", min = 1, max = 3000, initial = 2020, real = FALSE, id.name = "cust_yr")
  cust_pd <- rk.XML.spinbox("Start Period", min = 1, max = 365, initial = 1, real = FALSE, id.name = "cust_pd")

  frm_cust_df <- rk.XML.frame(
    cust_df, cust_y, cust_xreg,
    cust_freq, rk.XML.row(cust_yr, cust_pd),
    label = "Dynamic Regression Input (Data Frame)", id.name = "frm_cust_df"
  )

  # Tab 2: ARIMA Orders & Future xreg
  cust_p <- rk.XML.spinbox("AR Order (p)", min = 0, max = 10, initial = 0, real = FALSE, id.name = "cust_p")
  cust_d <- rk.XML.spinbox("Differencing (d)", min = 0, max = 3, initial = 1, real = FALSE, id.name = "cust_d")
  cust_q <- rk.XML.spinbox("MA Order (q)", min = 0, max = 10, initial = 1, real = FALSE, id.name = "cust_q")

  cust_P <- rk.XML.spinbox("Seasonal AR (P)", min = 0, max = 5, initial = 0, real = FALSE, id.name = "cust_P")
  cust_D <- rk.XML.spinbox("Seasonal Diff (D)", min = 0, max = 2, initial = 1, real = FALSE, id.name = "cust_D")
  cust_Q <- rk.XML.spinbox("Seasonal MA (Q)", min = 0, max = 5, initial = 1, real = FALSE, id.name = "cust_Q")

  frm_arima_ord <- rk.XML.frame(
    rk.XML.row(cust_p, cust_d, cust_q),
    rk.XML.row(cust_P, cust_D, cust_Q),
    label = "ARIMA(p,d,q)(P,D,Q) Specification"
  )

  cust_const <- rk.XML.cbox("Include Constant / Drift (include.constant = TRUE)", value = "1", chk = TRUE, id.name = "cust_const")
  cust_bc <- rk.XML.cbox("Apply Auto Box-Cox Transformation (lambda = 'auto')", value = "1", chk = FALSE, id.name = "cust_bc")
  cust_h <- rk.XML.spinbox("Forecast Horizon (h - Used when no xreg)", min = 1, max = 240, initial = 12, real = FALSE, id.name = "cust_h")

  # Selector independiente para el Data Frame de regresores futuros (xreg futuros)
  cust_new_vs <- rk.XML.varselector(id.name = "cust_new_vs", label = "Future Regressors Data Frames")
  cust_newdf <- rk.XML.varslot("Future Regressors Data Frame (newxreg - Required if xreg used)", source = "cust_new_vs", classes = "data.frame", required = FALSE, id.name = "cust_newdf")
  frm_cust_newx <- rk.XML.frame(cust_newdf, label = "Future Predictors for Forecasting (xreg)", id.name = "frm_cust_newx")

  # Tab 3: Plot Options
  cust_theme <- rk.XML.dropdown("Plot Theme (ggplot2)", options = list(
    "Minimal (Clean business look)" = list(val = "minimal", chk = TRUE),
    "Classic (Scientific)" = list(val = "classic"),
    "Black & White (Grid)" = list(val = "bw")
  ), id.name = "cust_theme")
  cust_plot_main <- rk.XML.input("Main Title (Leave empty for default)", id.name = "cust_plot_main")
  cust_plot_xlab <- rk.XML.input("X-Axis Label (Leave empty for default)", id.name = "cust_plot_xlab")
  cust_plot_ylab <- rk.XML.input("Y-Axis Label (Leave empty for default)", id.name = "cust_plot_ylab")
  frm_cust_plot <- rk.XML.frame(cust_theme, cust_plot_main, cust_plot_xlab, cust_plot_ylab, label = "Plot Customization")

  # Tab 4: Output
  cust_save_fc <- rk.XML.saveobj("Save Forecast Object as", initial = "custom_forecast", chk = TRUE, id.name = "cust_save_fc")
  cust_save_mod <- rk.XML.saveobj("Save ARIMA Model Object as", initial = "custom_model", chk = TRUE, id.name = "cust_save_mod")
  cust_plot_w <- rk.XML.spinbox("HTML Plot Width (pixels)", min = 100, max = 5000, initial = 800, real = FALSE, id.name = "cust_plot_w")
  cust_plot_h <- rk.XML.spinbox("HTML Plot Height (pixels)", min = 100, max = 5000, initial = 600, real = FALSE, id.name = "cust_plot_h")
  cust_plot_res <- rk.XML.spinbox("Resolution (DPI)", min = 72, max = 600, initial = 120, real = FALSE, id.name = "cust_plot_res")
  frm_cust_graph <- rk.XML.frame(rk.XML.row(cust_plot_w, cust_plot_h, cust_plot_res), label = "HTML Graphics Size & Resolution")
  cust_save_plot <- rk.XML.saveobj("Save Plot (ggplot2) as", initial = "custom_plot", chk = FALSE, id.name = "cust_save_plot")

  cust_preview <- rk.XML.preview(label = "Preview Custom ARIMA Plot")

  # --- Logic (Auto-Focus dual + Gray-Out) ---
  cond_cust_ts <- rk.XML.convert(sources = list(string = cust_src_mode), mode = c(equals = "ts"), id.name = "cond_cust_ts")
  cond_cust_df <- rk.XML.convert(sources = list(string = cust_src_mode), mode = c(equals = "df"), id.name = "cond_cust_df")

  # Regla de Oro #11: Script GUI para alternar Auto-Focus sin bloquear al volver a modo TS
  cust_gui_script <- XiMpLe::XMLNode("script", '
    gui.addChangeCommand("cust_src_mode.string", "update_cust_root()");
    gui.addChangeCommand("cust_df.available", "update_cust_root()");
    function update_cust_root() {
       var mode = gui.getValue("cust_src_mode.string");
       var df = gui.getValue("cust_df.available");
       if (mode === "df") {
          if (df !== "") {
             gui.setValue("cust_vs.root", df);
          } else {
             gui.setValue("cust_vs.root", "");
          }
       } else {
          gui.setValue("cust_vs.root", "");
       }
    }
  ')

  logic_cust <- rk.XML.logic(
    cond_cust_ts, cond_cust_df,
    rk.XML.connect(governor = cond_cust_ts, client = frm_cust_ts, set = "enabled"),
    rk.XML.connect(governor = cond_cust_df, client = frm_cust_df, set = "enabled"),
    rk.XML.connect(governor = cond_cust_df, client = frm_cust_newx, set = "enabled"),
    rk.XML.connect(governor = cond_cust_df, client = cust_new_vs, set = "enabled"),
    cust_gui_script
  )

  # --- Layout ---
  tab_cust <- rk.XML.tabbook(tabs = list(
    "1. Data & Regressors" = rk.XML.row(
      cust_vs,
      rk.XML.col(cust_src_mode, frm_cust_ts, frm_cust_df, rk.XML.stretch())
    ),
    "2. ARIMA Order & Horizon" = rk.XML.row(
      cust_new_vs,
      rk.XML.col(frm_arima_ord, cust_const, cust_bc, cust_h, frm_cust_newx, rk.XML.stretch())
    ),
    "3. Plot Options" = rk.XML.col(frm_cust_plot, rk.XML.stretch()),
    "4. Output" = rk.XML.col(
      rk.XML.frame(cust_save_mod, cust_save_fc, label = "Save Objects to Workspace"),
      frm_cust_graph,
      rk.XML.frame(cust_save_plot, label = "Save Plot Object"),
      rk.XML.stretch()
    )
  ))

  dialog_cust <- rk.XML.dialog(
    rk.XML.col(tab_cust, cust_preview),
    label = "2. Custom ARIMA & Dynamic Regression (xreg)"
  )

  # --- JavaScript ---

  js_calc_cust <- "
    var mode = getValue('cust_src_mode');
    var p = getValue('cust_p'); var d = getValue('cust_d'); var q = getValue('cust_q');
    var P = getValue('cust_P'); var D = getValue('cust_D'); var Q = getValue('cust_Q');
    var diff_total = parseInt(d, 10) + parseInt(D, 10);
    var inc_const = (getValue('cust_const') === '1' && diff_total <= 1) ? 'TRUE' : 'FALSE';
    var do_bc = getValue('cust_bc') === '1';
    var h = getValue('cust_h');

    var theme = getValue('cust_theme');
    var main_tit = cleanStr(getValue('cust_plot_main'));
    var x_tit = cleanStr(getValue('cust_plot_xlab'));
    var y_tit = cleanStr(getValue('cust_plot_ylab'));

    var has_xreg = false;
    var newdf = '';
    var src_label = '';

    if (mode === 'ts') {
        var ts_obj = getValue('cust_ts');
        src_label = ts_obj;
        echo('x_ts <- ' + ts_obj + '\\n');
    } else {
        var df = getValue('cust_df');
        var y_col = parseVar(getValue('cust_y'));
        var x_raw = getValue('cust_xreg');
        var freq = getValue('cust_freq');
        var yr = getValue('cust_yr');
        var pd = getValue('cust_pd');
        newdf = getValue('cust_newdf');
        src_label = y_col;

        echo('x_ts <- stats::ts(' + df + '[[\"' + y_col + '\"]], frequency = ' + freq + ', start = c(' + yr + ', ' + pd + '))\\n');

        if (x_raw !== '') {
            var x_arr = x_raw.split('\\n').map(parseVar).filter(Boolean);
            if (x_arr.length > 0) {
                has_xreg = true;
                var x_cols_str = 'c(' + x_arr.map(function(v){ return '\"' + v + '\"'; }).join(', ') + ')';
                echo('xreg_cols <- ' + x_cols_str + '\\n');
                echo('xreg_mat <- as.matrix(' + df + '[, xreg_cols, drop = FALSE])\\n');
            }
        }
    }

    echo('if (anyNA(x_ts)) stop(\"Target series contains NAs. Please impute missing values first.\")\\n');
    if (do_bc) {
        echo('if (any(x_ts <= 0, na.rm = TRUE)) stop(\"Box-Cox transformation requires strictly positive values (> 0).\")\\n');
        echo('lam_val <- \"auto\"\\n');
    } else {
        echo('lam_val <- NULL\\n');
    }

    var xreg_arg = has_xreg ? ', xreg = xreg_mat' : '';

    echo('\\nif (stats::frequency(x_ts) > 1) {\\n');
    echo('  custom_model <- forecast::Arima(x_ts, order = c(' + p + ', ' + d + ', ' + q + '), seasonal = list(order = c(' + P + ', ' + D + ', ' + Q + '), period = stats::frequency(x_ts)), include.constant = ' + inc_const + ', lambda = lam_val' + xreg_arg + ')\\n');
    echo('} else {\\n');
    echo('  custom_model <- forecast::Arima(x_ts, order = c(' + p + ', ' + d + ', ' + q + '), include.constant = ' + inc_const + ', lambda = lam_val' + xreg_arg + ')\\n');
    echo('}\\n\\n');

    // Tabla de coeficientes con z-value y p-value en R base
    echo('cf <- stats::coef(custom_model)\\n');
    echo('se <- sqrt(diag(stats::vcov(custom_model)))\\n');
    echo('se_vec <- rep(NA_real_, length(cf)); names(se_vec) <- names(cf)\\n');
    echo('se_vec[names(se)] <- se\\n');
    echo('z_val <- cf / se_vec\\n');
    echo('p_val <- 2 * (1 - stats::pnorm(abs(z_val)))\\n');
    echo('coef_table <- data.frame(\\n');
    echo('  Term = names(cf), Estimate = round(as.numeric(cf), 4), Std_Error = round(as.numeric(se_vec), 4),\\n');
    echo('  z_value = round(as.numeric(z_val), 4), p_value = round(as.numeric(p_val), 4),\\n');
    echo('  Sig = ifelse(is.na(p_val), \"\", ifelse(p_val < 0.001, \"***\", ifelse(p_val < 0.01, \"**\", ifelse(p_val < 0.05, \"*\", ifelse(p_val < 0.1, \".\", \"\")))))\\n');
    echo(')\\n\\n');

    // Métricas de ajuste
    echo('acc_c <- forecast::accuracy(custom_model)\\n');
    echo('fit_metrics <- data.frame(AIC = round(custom_model$aic, 2), AICc = round(custom_model$aicc, 2), BIC = round(custom_model$bic, 2), RMSE = round(acc_c[1, \"RMSE\"], 4), MAE = round(acc_c[1, \"MAE\"], 4), MAPE = round(acc_c[1, \"MAPE\"], 4))\\n\\n');

    // Pronóstico o solo ajuste
    var default_tit = 'Custom ARIMA(' + p + ',' + d + ',' + q + ')(' + P + ',' + D + ',' + Q + '): ' + src_label;
    var title_str = (main_tit !== '') ? main_tit : default_tit;

    if (has_xreg && newdf === '') {
        echo('custom_forecast <- NULL\\n');
        echo('p <- ggplot2::autoplot(x_ts, series = \"Actual\") +\\n');
        echo('     ggplot2::autolayer(stats::fitted(custom_model), series = \"Fitted\") +\\n');
        echo('     ggplot2::theme_' + theme + '() + ggplot2::theme(legend.position = \"bottom\")\\n');
    } else if (has_xreg && newdf !== '') {
        echo('if (!all(xreg_cols %in% colnames(' + newdf + '))) stop(\"Future Regressors Data Frame is missing required xreg columns.\")\\n');
        echo('newxreg_mat <- as.matrix(' + newdf + '[, xreg_cols, drop = FALSE])\\n');
        echo('custom_forecast <- forecast::forecast(custom_model, xreg = newxreg_mat)\\n');
        echo('p <- ggplot2::autoplot(custom_forecast) + ggplot2::theme_' + theme + '() + ggplot2::theme(legend.position = \"bottom\")\\n');
    } else {
        echo('custom_forecast <- forecast::forecast(custom_model, h = ' + h + ')\\n');
        echo('p <- ggplot2::autoplot(custom_forecast) + ggplot2::theme_' + theme + '() + ggplot2::theme(legend.position = \"bottom\")\\n');
    }

    echo('p <- p + ggplot2::labs(title = \"' + title_str + '\"');
    if (x_tit !== '') echo(', x = \"' + x_tit + '\"');
    if (y_tit !== '') echo(', y = \"' + y_tit + '\"');
    echo(')\\n');
  "

  js_print_cust <- "
    var w = getValue('cust_plot_w');
    var h = getValue('cust_plot_h');
    var res = getValue('cust_plot_res');

    if (typeof is_preview !== 'undefined' && is_preview) {
        echo('print(p)\\n');
    }

    if (typeof is_preview === 'undefined' || !is_preview) {
        echo('rk.header(\"2. Custom ARIMA & Dynamic Regression Results\")\\n');

        echo('rk.graph.on(width = ' + w + ', height = ' + h + ', res = ' + res + ')\\n');
        echo('print(p)\\n');
        echo('rk.graph.off()\\n\\n');

        echo('rk.header(\"Model Parameters (Coefficients & p-values)\", level = 3)\\n');
        echo('rk.print(coef_table)\\n');

        echo('rk.header(\"Goodness of Fit & Accuracy\", level = 3)\\n');
        echo('rk.print(fit_metrics)\\n');

        echo('if (!is.null(custom_forecast)) {\\n');
        echo('  rk.header(\"Forecasted Values\", level = 3)\\n');
        echo('  rk.print(as.data.frame(custom_forecast))\\n');
        echo('} else {\\n');
        echo('  rk.print(\"<i>Note: Model fitted with external regressors (xreg). Provide a Future Regressors Data Frame to generate h-step forecasts.</i>\")\\n');
        echo('}\\n');

        if (getValue('cust_save_mod.active') || getValue('cust_save_fc.active') || getValue('cust_save_plot.active')) {
            echo('rk.print(\"<hr>\")\\n');
        }
        if (getValue('cust_save_mod.active')) {
            echo('rk.print(paste0(\"<b>ARIMA model saved as: </b><code>\", \"' + getValue('cust_save_mod') + '\", \"</code><br>\"))\\n');
        }
        if (getValue('cust_save_fc.active')) {
            echo('rk.print(paste0(\"<b>Forecast object saved as: </b><code>\", \"' + getValue('cust_save_fc') + '\", \"</code><br>\"))\\n');
        }
        if (getValue('cust_save_plot.active')) {
            echo('p$plot_env <- emptyenv()\\n');
            echo('custom_plot <- p\\n');
            echo('rk.print(paste0(\"<b>Plot object (ggplot2) saved as: </b><code>\", \"' + getValue('cust_save_plot') + '\", \"</code>\"))\\n');
        }
    }
  "

  comp_custom <- rk.plugin.component(
    "2. Custom ARIMA & Dynamic Regression (xreg)",
    xml = list(dialog = dialog_cust, logic = logic_cust),
    js = list(require = c("forecast", "ggplot2"), globals = js_helpers, calculate = js_calc_cust, printout = js_print_cust),
    hierarchy = h_models
  )

  # =========================================================================================
  # 4. MODULE 3: 3. Apply Saved Model (SPSS "Apply Time Series Models")
  # =========================================================================================

  # --- UI Elements ---
  app_vs <- rk.XML.varselector(id.name = "app_vs")
  app_mod <- rk.XML.varslot("Saved Model Object (Arima / ets)", source = "app_vs", classes = c("Arima", "ARIMA", "ets"), required = TRUE, id.name = "app_mod")

  app_mode <- rk.XML.radio("Application Mode", options = list(
    "Apply Model to New Time Series (ts)" = list(val = "ts", chk = TRUE),
    "Forecast Directly from Saved Model (No new data)" = list(val = "direct")
  ), id.name = "app_mode")

  app_ts <- rk.XML.varslot("New Time Series (ts)", source = "app_vs", classes = "ts", required = FALSE, id.name = "app_ts")

  app_reest <- rk.XML.radio("Parameter Handling", options = list(
    "Keep Saved Parameters (No re-estimation — SPSS Apply Mode)" = list(val = "keep", chk = TRUE),
    "Re-estimate Parameters on New Data (Keep Model Structure)" = list(val = "refit")
  ), id.name = "app_reest")

  frm_app_new <- rk.XML.frame(app_ts, app_reest, label = "New Data Options", id.name = "frm_app_new")
  app_h <- rk.XML.spinbox("Forecast Horizon (h)", min = 1, max = 240, initial = 12, real = FALSE, id.name = "app_h")

  # Plot Options
  app_theme <- rk.XML.dropdown("Plot Theme (ggplot2)", options = list(
    "Minimal (Clean business look)" = list(val = "minimal", chk = TRUE),
    "Classic (Scientific)" = list(val = "classic"),
    "Black & White (Grid)" = list(val = "bw")
  ), id.name = "app_theme")
  app_plot_main <- rk.XML.input("Main Title (Leave empty for default)", id.name = "app_plot_main")
  app_plot_xlab <- rk.XML.input("X-Axis Label (Leave empty for default)", id.name = "app_plot_xlab")
  app_plot_ylab <- rk.XML.input("Y-Axis Label (Leave empty for default)", id.name = "app_plot_ylab")
  frm_app_plot <- rk.XML.frame(app_theme, app_plot_main, app_plot_xlab, app_plot_ylab, label = "Plot Customization")

  # Output Options
  app_save_fc <- rk.XML.saveobj("Save Applied Forecast as", initial = "applied_forecast", chk = TRUE, id.name = "app_save_fc")
  app_save_mod <- rk.XML.saveobj("Save Applied Model as", initial = "applied_model", chk = FALSE, id.name = "app_save_mod")

  app_plot_w <- rk.XML.spinbox("HTML Plot Width (pixels)", min = 100, max = 5000, initial = 800, real = FALSE, id.name = "app_plot_w")
  app_plot_h <- rk.XML.spinbox("HTML Plot Height (pixels)", min = 100, max = 5000, initial = 600, real = FALSE, id.name = "app_plot_h")
  app_plot_res <- rk.XML.spinbox("Resolution (DPI)", min = 72, max = 600, initial = 120, real = FALSE, id.name = "app_plot_res")
  frm_app_graph <- rk.XML.frame(rk.XML.row(app_plot_w, app_plot_h, app_plot_res), label = "HTML Graphics Size & Resolution")
  app_save_plot <- rk.XML.saveobj("Save Plot (ggplot2) as", initial = "applied_plot", chk = FALSE, id.name = "app_save_plot")

  app_preview <- rk.XML.preview(label = "Preview Applied Forecast Plot")

  # --- Logic ---
  cond_app_ts <- rk.XML.convert(sources = list(string = app_mode), mode = c(equals = "ts"), id.name = "cond_app_ts")

  logic_app <- rk.XML.logic(
    cond_app_ts,
    rk.XML.connect(governor = cond_app_ts, client = frm_app_new, set = "enabled")
  )

  # --- Layout ---
  tab_app <- rk.XML.tabbook(tabs = list(
    "Model & New Data" = rk.XML.col(app_mod, app_mode, frm_app_new, app_h, rk.XML.stretch()),
    "Plot Options" = rk.XML.col(frm_app_plot, rk.XML.stretch()),
    "Output" = rk.XML.col(
      rk.XML.frame(app_save_fc, app_save_mod, label = "Save Objects to Workspace"),
      frm_app_graph,
      rk.XML.frame(app_save_plot, label = "Save Plot Object"),
      rk.XML.stretch()
    )
  ))

  dialog_app <- rk.XML.dialog(
    rk.XML.row(
      app_vs,
      rk.XML.col(tab_app, app_preview)
    ),
    label = "3. Apply Saved Model"
  )

  # --- JavaScript ---
  js_calc_app <- "
    var mod = getValue('app_mod');
    var mode = getValue('app_mode');
    var new_ts = getValue('app_ts');
    var reest = getValue('app_reest');
    var h = getValue('app_h');

    var theme = getValue('app_theme');
    var main_tit = cleanStr(getValue('app_plot_main'));
    var x_tit = cleanStr(getValue('app_plot_xlab'));
    var y_tit = cleanStr(getValue('app_plot_ylab'));

    if (mode === 'direct') {
        echo('applied_model <- ' + mod + '\\n');
        echo('if (!is.null(applied_model$xreg)) stop(\"Models with xreg require Custom ARIMA to supply newxreg.\")\\n');
        echo('applied_forecast <- forecast::forecast(applied_model, h = ' + h + ')\\n');
    } else {
        echo('if (!is.null(' + mod + '$xreg)) stop(\"Models fitted with external regressors (xreg) require Custom ARIMA to supply new xreg values.\")\\n');
        echo('new_y <- ' + new_ts + '\\n');
        echo('if (anyNA(new_y)) stop(\"New time series contains NAs. Please impute missing values first.\")\\n\\n');

        echo('if (inherits(' + mod + ', \"ets\")) {\\n');
        if (reest === 'keep') {
            echo('  applied_model <- forecast::ets(new_y, model = ' + mod + ', use.initial.values = TRUE)\\n');
        } else {
            echo('  m_str <- paste(' + mod + '$components[1:3], collapse = \"\")\\n');
            echo('  m_dmp <- isTRUE(as.logical(' + mod + '$components[4]))\\n');
            echo('  applied_model <- forecast::ets(new_y, model = m_str, damped = m_dmp, lambda = ' + mod + '$lambda)\\n');
        }
        echo('} else if (inherits(' + mod + ', \"Arima\")) {\\n');
        if (reest === 'keep') {
            echo('  applied_model <- forecast::Arima(new_y, model = ' + mod + ')\\n');
        } else {
            echo('  ord <- forecast::arimaorder(' + mod + ')\\n');
            echo('  inc_c <- any(c(\"drift\", \"intercept\") %in% names(stats::coef(' + mod + ')))\\n');
            echo('  if (length(ord) == 7) {\\n');
            echo('    applied_model <- forecast::Arima(new_y, order = ord[1:3], seasonal = list(order = ord[4:6], period = ord[7]), include.constant = inc_c, lambda = ' + mod + '$lambda)\\n');
            echo('  } else {\\n');
            echo('    applied_model <- forecast::Arima(new_y, order = ord[1:3], include.constant = inc_c, lambda = ' + mod + '$lambda)\\n');
            echo('  }\\n');
        }
        echo('} else {\\n');
        echo('  stop(\"Unsupported model class. Please provide an Arima or ets object.\")\\n');
        echo('}\\n');
        echo('applied_forecast <- forecast::forecast(applied_model, h = ' + h + ')\\n');
    }
    echo('\\n');

    echo('acc_app <- as.data.frame(forecast::accuracy(applied_model))\\n\\n');

    var title_str = (main_tit !== '') ? main_tit : 'Applied Forecast (' + mod + ')';
    echo('p <- ggplot2::autoplot(applied_forecast) + ggplot2::theme_' + theme + '() +\\n');
    echo('     ggplot2::labs(title = \"' + title_str + '\"');
    if (x_tit !== '') echo(', x = \"' + x_tit + '\"');
    if (y_tit !== '') echo(', y = \"' + y_tit + '\"');
    echo(') + ggplot2::theme(legend.position = \"bottom\")\\n');
  "

  js_print_app <- "
    var w = getValue('app_plot_w');
    var h = getValue('app_plot_h');
    var res = getValue('app_plot_res');

    if (typeof is_preview !== 'undefined' && is_preview) {
        echo('print(p)\\n');
    }

    if (typeof is_preview === 'undefined' || !is_preview) {
        echo('rk.header(\"3. Apply Saved Model Results\")\\n');

        echo('rk.graph.on(width = ' + w + ', height = ' + h + ', res = ' + res + ')\\n');
        echo('print(p)\\n');
        echo('rk.graph.off()\\n\\n');

        echo('rk.header(\"Applied Model Summary\", level = 3)\\n');
        echo('rk.print(summary(applied_model))\\n');

        echo('rk.header(\"Accuracy Metrics on Target Series\", level = 3)\\n');
        echo('rk.print(acc_app)\\n');

        echo('rk.header(\"Forecasted Values\", level = 3)\\n');
        echo('rk.print(as.data.frame(applied_forecast))\\n');

        if (getValue('app_save_fc.active') || getValue('app_save_mod.active') || getValue('app_save_plot.active')) {
            echo('rk.print(\"<hr>\")\\n');
        }
        if (getValue('app_save_fc.active')) {
            echo('rk.print(paste0(\"<b>Applied forecast saved as: </b><code>\", \"' + getValue('app_save_fc') + '\", \"</code><br>\"))\\n');
        }
        if (getValue('app_save_mod.active')) {
            echo('rk.print(paste0(\"<b>Applied model saved as: </b><code>\", \"' + getValue('app_save_mod') + '\", \"</code><br>\"))\\n');
        }
        if (getValue('app_save_plot.active')) {
            echo('p$plot_env <- emptyenv()\\n');
            echo('applied_plot <- p\\n');
            echo('rk.print(paste0(\"<b>Plot object (ggplot2) saved as: </b><code>\", \"' + getValue('app_save_plot') + '\", \"</code>\"))\\n');
        }
    }
  "

  comp_apply <- rk.plugin.component(
    "3. Apply Saved Model",
    xml = list(dialog = dialog_app, logic = logic_app),
    js = list(require = c("forecast", "ggplot2"), globals = js_helpers, calculate = js_calc_app, printout = js_print_app),
    hierarchy = h_models
  )

  # =========================================================================================
  # 5. MODULE 4: 4. Temporal Causal Modeling (VAR & Granger Causality)
  # =========================================================================================

  # --- UI Elements ---
  var_vs <- rk.XML.varselector(id.name = "var_vs")

  var_src_mode <- rk.XML.radio("Input Data Format", options = list(
    "Data Frame (Select 2 or more numeric columns)" = list(val = "df", chk = TRUE),
    "Multivariate Time Series (mts)" = list(val = "mts")
  ), id.name = "var_src_mode")

  var_df <- rk.XML.varslot("Data Frame", source = "var_vs", classes = "data.frame", required = FALSE, id.name = "var_df")
  var_cols <- rk.XML.varslot("Variables to Model (>= 2 Numeric Columns)", source = "var_vs", classes = c("numeric", "integer"), multi = TRUE, required = FALSE, id.name = "var_cols")

  var_freq <- rk.XML.dropdown("Frequency", options = list(
    "Monthly (12)" = list(val = "12", chk = TRUE),
    "Quarterly (4)" = list(val = "4"),
    "Yearly (1)" = list(val = "1"),
    "Weekly (52)" = list(val = "52")
  ), id.name = "var_freq")
  var_yr <- rk.XML.spinbox("Start Year", min = 1, max = 3000, initial = 2020, real = FALSE, id.name = "var_yr")
  var_pd <- rk.XML.spinbox("Start Period", min = 1, max = 52, initial = 1, real = FALSE, id.name = "var_pd")

  frm_var_df <- rk.XML.frame(var_df, var_cols, var_freq, rk.XML.row(var_yr, var_pd), label = "Data Frame Input", id.name = "frm_var_df")

  var_mts <- rk.XML.varslot("Multivariate Time Series (mts)", source = "var_vs", classes = c("mts", "ts"), required = FALSE, id.name = "var_mts")
  frm_var_mts <- rk.XML.frame(var_mts, label = "MTS Object Input", id.name = "frm_var_mts")

  # VAR Options
  var_lag_mode <- rk.XML.radio("Lag Order (p) Selection", options = list(
    "Auto-detect Optimal Lag via Information Criterion (VARselect)" = list(val = "auto", chk = TRUE),
    "Manual Fixed Lag Order (p)" = list(val = "manual")
  ), id.name = "var_lag_mode")

  var_lag_max <- rk.XML.spinbox("Max Lags to Search (lag.max)", min = 1, max = 24, initial = 6, real = FALSE, id.name = "var_lag_max")
  var_ic <- rk.XML.dropdown("Selection Criterion", options = list(
    "AIC (Akaike)" = list(val = "AIC(n)", chk = TRUE),
    "SC / BIC (Schwarz)" = list(val = "SC(n)"),
    "HQ (Hannan-Quinn)" = list(val = "HQ(n)"),
    "FPE (Final Prediction Error)" = list(val = "FPE(n)")
  ), id.name = "var_ic")
  frm_var_auto <- rk.XML.frame(var_lag_max, var_ic, label = "Automatic Lag Search", id.name = "frm_var_auto")

  var_lag_p <- rk.XML.spinbox("Fixed Lag Order (p)", min = 1, max = 24, initial = 2, real = FALSE, id.name = "var_lag_p")
  frm_var_man <- rk.XML.frame(var_lag_p, label = "Manual Lag", id.name = "frm_var_man")

  var_type <- rk.XML.dropdown("Deterministic Regressors", options = list(
    "Constant (Intercept)" = list(val = "const", chk = TRUE),
    "Trend" = list(val = "trend"),
    "Both (Constant + Trend)" = list(val = "both"),
    "None" = list(val = "none")
  ), id.name = "var_type")

  var_h <- rk.XML.spinbox("Forecast Horizon (n.ahead)", min = 1, max = 120, initial = 12, real = FALSE, id.name = "var_h")
  var_chk_granger <- rk.XML.cbox("Compute Granger Causality Tests (Cause -> Effect)", value = "1", chk = TRUE, id.name = "var_chk_granger")
  var_chk_irf <- rk.XML.cbox("Plot Impulse Response Functions (IRF)", value = "1", chk = FALSE, id.name = "var_chk_irf")

  # Output Options
  var_save_mod <- rk.XML.saveobj("Save VAR Model (varest) as", initial = "var_model", chk = TRUE, id.name = "var_save_mod")
  var_save_fc <- rk.XML.saveobj("Save VAR Forecast as", initial = "var_forecast", chk = FALSE, id.name = "var_save_fc")

  var_plot_w <- rk.XML.spinbox("HTML Plot Width (pixels)", min = 100, max = 5000, initial = 850, real = FALSE, id.name = "var_plot_w")
  var_plot_h <- rk.XML.spinbox("HTML Plot Height (pixels)", min = 100, max = 5000, initial = 650, real = FALSE, id.name = "var_plot_h")
  var_plot_res <- rk.XML.spinbox("Resolution (DPI)", min = 72, max = 600, initial = 120, real = FALSE, id.name = "var_plot_res")
  frm_var_graph <- rk.XML.frame(rk.XML.row(var_plot_w, var_plot_h, var_plot_res), label = "HTML Graphics Size & Resolution")
  var_save_plot <- rk.XML.saveobj("Save Forecast Plot (recorded) as", initial = "var_plot", chk = FALSE, id.name = "var_save_plot")

  var_preview <- rk.XML.preview(label = "Preview VAR Forecast Plot")

  # --- Logic ---
  cond_var_df  <- rk.XML.convert(sources = list(string = var_src_mode), mode = c(equals = "df"), id.name = "cond_var_df")
  cond_var_mts <- rk.XML.convert(sources = list(string = var_src_mode), mode = c(equals = "mts"), id.name = "cond_var_mts")
  cond_var_auto <- rk.XML.convert(sources = list(string = var_lag_mode), mode = c(equals = "auto"), id.name = "cond_var_auto")
  cond_var_man  <- rk.XML.convert(sources = list(string = var_lag_mode), mode = c(equals = "manual"), id.name = "cond_var_man")

  var_gui_script <- XiMpLe::XMLNode("script", '
    gui.addChangeCommand("var_src_mode.string", "update_var_root()");
    gui.addChangeCommand("var_df.available", "update_var_root()");
    function update_var_root() {
       var mode = gui.getValue("var_src_mode.string");
       var df = gui.getValue("var_df.available");
       if (mode === "df") {
          if (df !== "") {
             gui.setValue("var_vs.root", df);
          } else {
             gui.setValue("var_vs.root", "");
          }
       } else {
          gui.setValue("var_vs.root", "");
       }
    }
  ')

  logic_var <- rk.XML.logic(
    cond_var_df, cond_var_mts, cond_var_auto, cond_var_man,
    rk.XML.connect(governor = cond_var_df, client = frm_var_df, set = "enabled"),
    rk.XML.connect(governor = cond_var_mts, client = frm_var_mts, set = "enabled"),
    rk.XML.connect(governor = cond_var_auto, client = frm_var_auto, set = "enabled"),
    rk.XML.connect(governor = cond_var_man, client = frm_var_man, set = "enabled"),
    var_gui_script
  )

  # --- Layout ---
  tab_var <- rk.XML.tabbook(tabs = list(
    "1. Variables & Data" = rk.XML.col(var_src_mode, frm_var_df, frm_var_mts, rk.XML.stretch()),
    "2. VAR & Causality" = rk.XML.col(var_lag_mode, frm_var_auto, frm_var_man, var_type, var_h, var_chk_granger, var_chk_irf, rk.XML.stretch()),
    "3. Output" = rk.XML.col(
      rk.XML.frame(var_save_mod, var_save_fc, label = "Save Objects to Workspace"),
      frm_var_graph,
      rk.XML.frame(var_save_plot, label = "Save Plot Object"),
      rk.XML.stretch()
    )
  ))

  dialog_var <- rk.XML.dialog(
    rk.XML.row(
      var_vs,
      rk.XML.col(tab_var, var_preview)
    ),
    label = "4. Temporal Causal Modeling (VAR & Granger)"
  )

  # --- JavaScript ---
  js_calc_var <- "
    var mode = getValue('var_src_mode');
    var lag_mode = getValue('var_lag_mode');
    var lag_max = getValue('var_lag_max');
    var ic = getValue('var_ic');
    var lag_p = getValue('var_lag_p');
    var det_type = getValue('var_type');
    var h = getValue('var_h');
    var do_granger = getValue('var_chk_granger') === '1';

    if (mode === 'df') {
        var df = getValue('var_df');
        var cols_raw = getValue('var_cols');
        var freq = getValue('var_freq');
        var yr = getValue('var_yr');
        var pd = getValue('var_pd');

        var cols_arr = cols_raw.split('\\n').map(parseVar).filter(Boolean);
        if (cols_arr.length < 2) {
            echo('stop(\"Please select at least 2 numeric variables for a VAR model.\")\\n');
        } else {
            var cols_str = 'c(' + cols_arr.map(function(v){ return '\"' + v + '\"'; }).join(', ') + ')';
            echo('mts_data <- stats::ts(as.matrix(' + df + '[, ' + cols_str + ', drop = FALSE]), frequency = ' + freq + ', start = c(' + yr + ', ' + pd + '))\\n');
        }
    } else {
        var mts_obj = getValue('var_mts');
        echo('mts_data <- ' + mts_obj + '\\n');
        echo('if (NCOL(mts_data) < 2) stop(\"Multivariate time series must have at least 2 columns.\")\\n');
    }

    echo('mts_data <- stats::na.omit(mts_data)\\n\\n');

    echo('sel_tbl <- data.frame()\\n');
    if (lag_mode === 'auto') {
        echo('sel_res <- vars::VARselect(mts_data, lag.max = ' + lag_max + ', type = \"' + det_type + '\")\\n');
        echo('sel_tbl <- as.data.frame(t(sel_res$selection))\\n');
        echo('best_p <- as.numeric(sel_res$selection[\"' + ic + '\"])\\n');
        echo('if (is.na(best_p) || best_p < 1) best_p <- 1\\n');
        echo('var_model <- vars::VAR(mts_data, p = best_p, type = \"' + det_type + '\")\\n');
        echo('var_model$call$p <- best_p\\n\\n'); // <-- AGREGAR ESTA LÍNEA
    } else {
        echo('var_model <- vars::VAR(mts_data, p = ' + lag_p + ', type = \"' + det_type + '\")\\n\\n');
    }

    echo('var_forecast <- stats::predict(var_model, n.ahead = ' + h + ', ci = 0.95)\\n\\n');

    // Causalidad de Granger para todas las variables del sistema
    echo('granger_df <- data.frame()\\n');
    if (do_granger) {
        echo('v_names <- colnames(mts_data)\\n');
        echo('for (v in v_names) {\\n');
        echo('  g_res <- tryCatch(vars::causality(var_model, cause = v)$Granger, error = function(e) NULL)\\n');
        echo('  if (!is.null(g_res)) {\\n');
        echo('    eff <- paste(setdiff(v_names, v), collapse = \", \")\\n');
        echo('    pval <- as.numeric(g_res$p.value)\\n');
        echo('    granger_df <- rbind(granger_df, data.frame(\\n');
        echo('      Cause = v, Effect = eff,\\n');
        echo('      F_Stat = round(as.numeric(g_res$statistic), 4),\\n');
        echo('      df1 = as.numeric(g_res$parameter[1]), df2 = as.numeric(g_res$parameter[2]),\\n');
        echo('      P_Value = round(pval, 4),\\n');
        echo('      Conclusion = ifelse(pval < 0.05, \"Significant (Granger-causes)\", \"Not Significant\")\\n');
        echo('    ))\\n');
        echo('  }\\n');
        echo('}\\n');
    }
    echo('\\n');

    // Prueba de autocorrelación multivariada en residuos
    echo('var_diag_tbl <- tryCatch({\\n');
    echo('  pt <- vars::serial.test(var_model, lags.pt = min(12, floor(nrow(mts_data) / 3)), type = \"PT.asymptotic\")$serial\\n');
    echo('  data.frame(Test = \"Portmanteau (VAR Residuals)\", Chi_Sq = round(as.numeric(pt$statistic), 4), df = as.numeric(pt$parameter), P_Value = round(pt$p.value, 4), Conclusion = ifelse(pt$p.value >= 0.05, \"No residual autocorrelation\", \"Autocorrelation remains (Try higher p)\"))\\n');
    echo('}, error = function(e) data.frame())\\n');
  "

  js_print_var <- "
    var w = getValue('var_plot_w');
    var h = getValue('var_plot_h');
    var res = getValue('var_plot_res');
    var h_fc = getValue('var_h');
    var do_irf = getValue('var_chk_irf') === '1';

    if (typeof is_preview !== 'undefined' && is_preview) {
        echo('grDevices::devAskNewPage(FALSE)\\n');
        echo('plot(var_forecast, plot.type = \"multiple\")\\n');
    }

    if (typeof is_preview === 'undefined' || !is_preview) {
        echo('rk.header(\"4. Temporal Causal Modeling (VAR & Granger)\")\\n');

        echo('rk.graph.on(width = ' + w + ', height = ' + h + ', res = ' + res + ')\\n');
        echo('grDevices::devAskNewPage(FALSE)\\n');
        echo('plot(var_forecast, plot.type = \"multiple\")\\n');
        if (getValue('var_save_plot.active')) {
            echo('var_plot <- grDevices::recordPlot()\\n');
        }
        echo('rk.graph.off()\\n\\n');

        echo('if (nrow(sel_tbl) > 0) {\\n');
        echo('  rk.header(\"Optimal Lag Selection (VARselect)\", level = 3)\\n');
        echo('  rk.print(sel_tbl)\\n');
        echo('}\\n');

        echo('if (nrow(granger_df) > 0) {\\n');
        echo('  rk.header(\"Granger Causality Tests\", level = 3)\\n');
        echo('  rk.print(granger_df)\\n');
        echo('}\\n');

        echo('if (nrow(var_diag_tbl) > 0) {\\n');
        echo('  rk.header(\"Residual Serial Correlation Test\", level = 3)\\n');
        echo('  rk.print(var_diag_tbl)\\n');
        echo('}\\n');

        if (do_irf) {
            echo('rk.header(\"Impulse Response Functions (IRF)\", level = 3)\\n');
            echo('for (imp_v in colnames(mts_data)) {\\n');
            echo('  irf_single <- vars::irf(var_model, impulse = imp_v, n.ahead = ' + h_fc + ', boot = TRUE)\\n');
            echo('  rk.graph.on(width = ' + w + ', height = ' + h + ', res = ' + res + ')\\n');
            echo('  grDevices::devAskNewPage(FALSE)\\n');
            echo('  plot(irf_single)\\n');
            echo('  rk.graph.off()\\n');
            echo('}\\n\\n');
        }

        echo('rk.header(\"VAR Model Forecasts\", level = 3)\\n');
        echo('for (v_nm in names(var_forecast$fcst)) {\\n');
        echo('  rk.header(paste(\"Series:\", v_nm), level = 4)\\n');
        echo('  rk.print(as.data.frame(var_forecast$fcst[[v_nm]]))\\n');
        echo('}\\n');

        if (getValue('var_save_mod.active') || getValue('var_save_fc.active') || getValue('var_save_plot.active')) {
            echo('rk.print(\"<hr>\")\\n');
        }
        if (getValue('var_save_mod.active')) {
            echo('rk.print(paste0(\"<b>VAR model saved as: </b><code>\", \"' + getValue('var_save_mod') + '\", \"</code><br>\"))\\n');
        }
        if (getValue('var_save_fc.active')) {
            echo('rk.print(paste0(\"<b>VAR forecast saved as: </b><code>\", \"' + getValue('var_save_fc') + '\", \"</code><br>\"))\\n');
        }
        if (getValue('var_save_plot.active')) {
            echo('rk.print(paste0(\"<b>Plot object (recorded) saved as: </b><code>\", \"' + getValue('var_save_plot') + '\", \"</code>\"))\\n');
        }
    }
  "

  comp_var <- rk.plugin.component(
    "4. Temporal Causal Modeling (VAR & Granger)",
    xml = list(dialog = dialog_var, logic = logic_var),
    js = list(require = c("vars", "stats"), globals = js_helpers, calculate = js_calc_var, printout = js_print_var),
    hierarchy = h_models
  )

  # =========================================================================================
  # 6. BUILD SKELETON
  # =========================================================================================

  unlink("rk.ts.models", recursive = TRUE)

  rk.plugin.skeleton(
    about = package_about,
    path = ".",
    xml = list(dialog = dialog_exp, logic = logic_exp),
    js = list(
      require = c("forecast", "ggplot2"),
      globals = js_helpers,
      calculate = js_calc_exp,
      printout = js_print_exp
    ),
    components = list(comp_custom, comp_apply, comp_var),
    pluginmap = list(
      name = "1. Expert Modeler (Auto-ARIMA, ETS, Ensemble)",
      hierarchy = h_models
    ),
    dependencies = dependencies_node,
    create = c("pmap", "xml", "js", "desc", "rkh"),
    overwrite = TRUE,
    load = TRUE,
    show = FALSE
  )

  cat("\nPackage 'rk.ts.models' generated successfully.\n")
})
