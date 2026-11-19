// this code was generated using the rkwarddev package.
// perhaps don't make changes here, but in the rkwarddev script instead!

// define variables globally
    function cleanStr(val) {
        if(!val) return '';
        return val.replace(/'/g, "\\'").replace(/"/g, '\\"');
    }

    function parseVar(fullPath) {
        if (!fullPath) return '';
        var raw_col = '';
        if (fullPath.indexOf('[[') > -1) {
            var parts = fullPath.split('[[');
            var inner = parts[1].replace(']]', '');
            raw_col = inner.replace(/["']/g, '');
        } else if (fullPath.indexOf('$') > -1) {
            raw_col = fullPath.split('$')[1];
        } else {
            raw_col = fullPath;
        }
        return raw_col;
    }
  

function preview(){
	preprocess(true);
	calculate(true);
	printout(true);
}

function preprocess(is_preview){
	// add requirements etc. here
	if(is_preview) {
		echo("if(!base::require(forecast)){stop(" + i18n("Preview not available, because package forecast is not installed or cannot be loaded.") + ")}\n");
	} else {
		echo("require(forecast)\n");
	}	if(is_preview) {
		echo("if(!base::require(ggplot2)){stop(" + i18n("Preview not available, because package ggplot2 is not installed or cannot be loaded.") + ")}\n");
	} else {
		echo("require(ggplot2)\n");
	}
}

function calculate(is_preview){
	// read in variables from dialog


	// the R code to be evaluated

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

    echo('x_ts <- ' + ts_obj + '\n');
    echo('if (anyNA(x_ts)) stop("Series contains NAs. Please impute missing values first using rk.ts.prep.")\n\n');

    // 1. Outliers
    echo('out_table <- data.frame()\n');
    if (out_mode === 'none') {
        echo('x_clean <- x_ts\n');
    } else if (out_mode === 'fast') {
        echo('out_info <- forecast::tsoutliers(x_ts)\n');
        echo('x_clean <- forecast::tsclean(x_ts)\n');
        echo('if (length(out_info$index) > 0) {\n');
        echo('  out_table <- data.frame(Index = out_info$index, Original = round(as.numeric(x_ts[out_info$index]), 4), Replacement = round(as.numeric(out_info$replacements), 4))\n');
        echo('}\n');
    } else if (out_mode === 'tso') {
        echo('if (!requireNamespace("tsoutliers", quietly = TRUE)) stop("Package tsoutliers is required for Chen & Liu (AO/LS/TC) detection.")\n');
        echo('tso_res <- tsoutliers::tso(x_ts)\n');
        echo('x_clean <- tso_res$yadj\n');
        echo('if (nrow(tso_res$outliers) > 0) {\n');
        echo('  out_table <- as.data.frame(tso_res$outliers)\n');
        echo('}\n');
    }
    echo('\n');

    // 2. Box-Cox
    if (do_bc) {
        echo('if (any(x_clean <= 0, na.rm = TRUE)) stop("Box-Cox transformation requires strictly positive values (> 0).")\n');
        echo('lam_val <- "auto"\n');
    } else {
        echo('lam_val <- NULL\n');
    }
    echo('\n');

    // 3. Fit Candidate Models
    echo('comp_table <- data.frame()\n');
    if (scope === 'arima') {
        echo('expert_model <- forecast::auto.arima(x_clean, lambda = lam_val)\n');
        echo('expert_forecast <- forecast::forecast(expert_model, h = ' + h + ')\n');
        echo('acc_m <- forecast::accuracy(expert_model)\n');
        echo('comp_table <- data.frame(Model = paste("Auto-ARIMA:", as.character(expert_model)), RMSE = round(acc_m[1, "RMSE"], 4), MAE = round(acc_m[1, "MAE"], 4), MAPE = round(acc_m[1, "MAPE"], 4), AICc = round(expert_model$aicc, 2), Selected = "Yes")\n');
    } else if (scope === 'ets') {
        echo('expert_model <- forecast::ets(x_clean, lambda = lam_val)\n');
        echo('expert_forecast <- forecast::forecast(expert_model, h = ' + h + ')\n');
        echo('acc_m <- forecast::accuracy(expert_model)\n');
        echo('comp_table <- data.frame(Model = paste("ETS:", expert_model$method), RMSE = round(acc_m[1, "RMSE"], 4), MAE = round(acc_m[1, "MAE"], 4), MAPE = round(acc_m[1, "MAPE"], 4), AICc = round(expert_model$aicc, 2), Selected = "Yes")\n');
    } else if (scope === 'both') {
        echo('mod_arima <- forecast::auto.arima(x_clean, lambda = lam_val)\n');
        echo('mod_ets   <- forecast::ets(x_clean, lambda = lam_val)\n');
        echo('acc_a <- forecast::accuracy(mod_arima)\n');
        echo('acc_e <- forecast::accuracy(mod_ets)\n');
        echo('win_arima <- acc_a[1, "RMSE"] <= acc_e[1, "RMSE"]\n');
        echo('if (win_arima) { expert_model <- mod_arima } else { expert_model <- mod_ets }\n');
        echo('expert_forecast <- forecast::forecast(expert_model, h = ' + h + ')\n');
        echo('comp_table <- data.frame(\n');
        echo('  Model = c(paste("Auto-ARIMA:", as.character(mod_arima)), paste("ETS:", mod_ets$method)),\n');
        echo('  RMSE  = round(c(acc_a[1, "RMSE"], acc_e[1, "RMSE"]), 4),\n');
        echo('  MAE   = round(c(acc_a[1, "MAE"], acc_e[1, "MAE"]), 4),\n');
        echo('  MAPE  = round(c(acc_a[1, "MAPE"], acc_e[1, "MAPE"]), 4),\n');
        echo('  AICc  = round(c(mod_arima$aicc, mod_ets$aicc), 2),\n');
        echo('  Selected = c(ifelse(win_arima, "Winner (Lowest RMSE)", "No"), ifelse(!win_arima, "Winner (Lowest RMSE)", "No"))\n');
        echo(')\n');
    } else if (scope === 'ensemble') {
        echo('mod_arima <- forecast::auto.arima(x_clean, lambda = lam_val)\n');
        echo('mod_ets   <- forecast::ets(x_clean, lambda = lam_val)\n');
        echo('fc_a <- forecast::forecast(mod_arima, h = ' + h + ')\n');
        echo('fc_e <- forecast::forecast(mod_ets, h = ' + h + ')\n');
        echo('fc_ens <- fc_a\n');
        echo('fc_ens$method <- "Ensemble (Auto-ARIMA + ETS)"\n');
        echo('fc_ens$mean   <- (fc_a$mean + fc_e$mean) / 2\n');
        echo('fc_ens$lower  <- (fc_a$lower + fc_e$lower) / 2\n');
        echo('fc_ens$upper  <- (fc_a$upper + fc_e$upper) / 2\n');
        echo('fc_ens$fitted <- (stats::fitted(mod_arima) + stats::fitted(mod_ets)) / 2\n');
        echo('fc_ens$residuals <- x_clean - fc_ens$fitted\n');
        echo('expert_forecast <- fc_ens\n');
        echo('expert_model <- list(arima = mod_arima, ets = mod_ets, method = "Ensemble")\n');
        echo('acc_a <- forecast::accuracy(mod_arima)\n');
        echo('acc_e <- forecast::accuracy(mod_ets)\n');
        echo('acc_ens <- forecast::accuracy(expert_forecast)\n');
        echo('comp_table <- data.frame(\n');
        echo('  Model = c(paste("Auto-ARIMA:", as.character(mod_arima)), paste("ETS:", mod_ets$method), "Ensemble (Average)"),\n');
        echo('  RMSE  = round(c(acc_a[1, "RMSE"], acc_e[1, "RMSE"], acc_ens[1, "RMSE"]), 4),\n');
        echo('  MAE   = round(c(acc_a[1, "MAE"], acc_e[1, "MAE"], acc_ens[1, "MAE"]), 4),\n');
        echo('  MAPE  = round(c(acc_a[1, "MAPE"], acc_e[1, "MAPE"], acc_ens[1, "MAPE"]), 4),\n');
        echo('  Selected = c("Component", "Component", "Active Ensemble")\n');
        echo(')\n');
    }
    echo('\n');

    // 4. Residual Diagnostics
    echo('res_diag_tbl <- data.frame()\n');
    if (do_diag) {
        echo('res_vec <- stats::na.omit(stats::residuals(expert_forecast))\n');
        echo('n_r <- length(res_vec); m_r <- stats::frequency(x_clean)\n');
        echo('lb_lag <- max(1, if (m_r > 1) min(2 * m_r, floor(n_r / 5)) else min(10, floor(n_r / 5)))\n');
        echo('fit_df <- if (inherits(expert_model, "Arima")) length(stats::coef(expert_model)) else 0\n');
        echo('if (lb_lag <= fit_df) lb_lag <- fit_df + 1\n');
        echo('tryCatch({\n');
        echo('  lb <- stats::Box.test(res_vec, lag = lb_lag, type = "Ljung-Box", fitdf = fit_df)\n');
        echo('  lb_msg <- ifelse(lb$p.value >= 0.05, "White Noise (Adequate Fit)", "Residual Autocorrelation Remains")\n');
        echo('  res_diag_tbl <- data.frame(Test = "Ljung-Box (Residuals)", Statistic = round(as.numeric(lb$statistic), 4), Lag = lb_lag, P_Value = round(lb$p.value, 4), Conclusion = lb_msg)\n');
        echo('}, error = function(e) {})\n');
    }
    echo('\n');

    // 5. ggplot
    var title_str = (main_tit !== '') ? main_tit : 'Expert Modeler Forecast: ' + ts_obj;
    echo('p <- ggplot2::autoplot(expert_forecast) + ggplot2::theme_' + theme + '() +\n');
    echo('     ggplot2::labs(title = "' + title_str + '"');
    if (x_tit !== '') echo(', x = "' + x_tit + '"');
    if (y_tit !== '') echo(', y = "' + y_tit + '"');
    echo(') + ggplot2::theme(legend.position = "bottom")\n');
  
}

function printout(is_preview){
	// read in variables from dialog


	// printout the results
	if(!is_preview) {
		new Header(i18n("1. Expert Modeler (Auto-ARIMA, ETS, Ensemble) results")).print();	
	}
    var w = getValue('exp_plot_w');
    var h = getValue('exp_plot_h');
    var res = getValue('exp_plot_res');

    if (typeof is_preview !== 'undefined' && is_preview) {
        echo('print(p)\n');
    }

    if (typeof is_preview === 'undefined' || !is_preview) {
        echo('rk.header("1. Expert Modeler Results")\n');

        echo('rk.graph.on(width = ' + w + ', height = ' + h + ', res = ' + res + ')\n');
        echo('print(p)\n');
        echo('rk.graph.off()\n\n');

        echo('rk.header("Model Comparison & Accuracy Metrics (In-Sample)", level = 3)\n');
        echo('rk.print(comp_table)\n');

        echo('if (nrow(out_table) > 0) {\n');
        echo('  rk.header("Detected & Adjusted Outliers", level = 3)\n');
        echo('  rk.print(out_table)\n');
        echo('}\n');

        echo('if (nrow(res_diag_tbl) > 0) {\n');
        echo('  rk.header("Residual Diagnostics", level = 3)\n');
        echo('  rk.print(res_diag_tbl)\n');
        echo('}\n');

        echo('rk.header("Forecasted Values", level = 3)\n');
        echo('rk.print(as.data.frame(expert_forecast))\n');

        if (getValue('exp_save_fc.active') || getValue('exp_save_mod.active') || getValue('exp_save_plot.active')) {
            echo('rk.print("<hr>")\n');
        }
        if (getValue('exp_save_fc.active')) {
            echo('rk.print(paste0("<b>Forecast object saved as: </b><code>", "' + getValue('exp_save_fc') + '", "</code><br>"))\n');
        }
        if (getValue('exp_save_mod.active')) {
            echo('rk.print(paste0("<b>Model object saved as: </b><code>", "' + getValue('exp_save_mod') + '", "</code><br>"))\n');
        }
        if (getValue('exp_save_plot.active')) {
            echo('p$plot_env <- emptyenv()\n');
            echo('expert_plot <- p\n');
            echo('rk.print(paste0("<b>Plot object (ggplot2) saved as: </b><code>", "' + getValue('exp_save_plot') + '", "</code>"))\n');
        }
    }
  
	if(!is_preview) {
		//// save result object
		// read in saveobject variables
		var expSaveFc = getValue("exp_save_fc");
		var expSaveFcActive = getValue("exp_save_fc.active");
		var expSaveFcParent = getValue("exp_save_fc.parent");		var expSaveMod = getValue("exp_save_mod");
		var expSaveModActive = getValue("exp_save_mod.active");
		var expSaveModParent = getValue("exp_save_mod.parent");		var expSavePlot = getValue("exp_save_plot");
		var expSavePlotActive = getValue("exp_save_plot.active");
		var expSavePlotParent = getValue("exp_save_plot.parent");
		// assign object to chosen environment
		if(expSaveFcActive) {
			echo(".GlobalEnv$" + expSaveFc + " <- expert_forecast\n");
		}
		if(expSaveModActive) {
			echo(".GlobalEnv$" + expSaveMod + " <- expert_model\n");
		}
		if(expSavePlotActive) {
			echo(".GlobalEnv$" + expSavePlot + " <- expert_plot\n");
		}	
	}

}

