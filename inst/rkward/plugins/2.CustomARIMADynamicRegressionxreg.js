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
        echo('x_ts <- ' + ts_obj + '\n');
    } else {
        var df = getValue('cust_df');
        var y_col = parseVar(getValue('cust_y'));
        var x_raw = getValue('cust_xreg');
        var freq = getValue('cust_freq');
        var yr = getValue('cust_yr');
        var pd = getValue('cust_pd');
        newdf = getValue('cust_newdf');
        src_label = y_col;

        echo('x_ts <- stats::ts(' + df + '[["' + y_col + '"]], frequency = ' + freq + ', start = c(' + yr + ', ' + pd + '))\n');

        if (x_raw !== '') {
            var x_arr = x_raw.split('\n').map(parseVar).filter(Boolean);
            if (x_arr.length > 0) {
                has_xreg = true;
                var x_cols_str = 'c(' + x_arr.map(function(v){ return '"' + v + '"'; }).join(', ') + ')';
                echo('xreg_cols <- ' + x_cols_str + '\n');
                echo('xreg_mat <- as.matrix(' + df + '[, xreg_cols, drop = FALSE])\n');
            }
        }
    }

    echo('if (anyNA(x_ts)) stop("Target series contains NAs. Please impute missing values first.")\n');
    if (do_bc) {
        echo('if (any(x_ts <= 0, na.rm = TRUE)) stop("Box-Cox transformation requires strictly positive values (> 0).")\n');
        echo('lam_val <- "auto"\n');
    } else {
        echo('lam_val <- NULL\n');
    }

    var xreg_arg = has_xreg ? ', xreg = xreg_mat' : '';

    echo('\nif (stats::frequency(x_ts) > 1) {\n');
    echo('  custom_model <- forecast::Arima(x_ts, order = c(' + p + ', ' + d + ', ' + q + '), seasonal = list(order = c(' + P + ', ' + D + ', ' + Q + '), period = stats::frequency(x_ts)), include.constant = ' + inc_const + ', lambda = lam_val' + xreg_arg + ')\n');
    echo('} else {\n');
    echo('  custom_model <- forecast::Arima(x_ts, order = c(' + p + ', ' + d + ', ' + q + '), include.constant = ' + inc_const + ', lambda = lam_val' + xreg_arg + ')\n');
    echo('}\n\n');

    // Tabla de coeficientes con z-value y p-value en R base
    echo('cf <- stats::coef(custom_model)\n');
    echo('se <- sqrt(diag(stats::vcov(custom_model)))\n');
    echo('se_vec <- rep(NA_real_, length(cf)); names(se_vec) <- names(cf)\n');
    echo('se_vec[names(se)] <- se\n');
    echo('z_val <- cf / se_vec\n');
    echo('p_val <- 2 * (1 - stats::pnorm(abs(z_val)))\n');
    echo('coef_table <- data.frame(\n');
    echo('  Term = names(cf), Estimate = round(as.numeric(cf), 4), Std_Error = round(as.numeric(se_vec), 4),\n');
    echo('  z_value = round(as.numeric(z_val), 4), p_value = round(as.numeric(p_val), 4),\n');
    echo('  Sig = ifelse(is.na(p_val), "", ifelse(p_val < 0.001, "***", ifelse(p_val < 0.01, "**", ifelse(p_val < 0.05, "*", ifelse(p_val < 0.1, ".", "")))))\n');
    echo(')\n\n');

    // Métricas de ajuste
    echo('acc_c <- forecast::accuracy(custom_model)\n');
    echo('fit_metrics <- data.frame(AIC = round(custom_model$aic, 2), AICc = round(custom_model$aicc, 2), BIC = round(custom_model$bic, 2), RMSE = round(acc_c[1, "RMSE"], 4), MAE = round(acc_c[1, "MAE"], 4), MAPE = round(acc_c[1, "MAPE"], 4))\n\n');

    // Pronóstico o solo ajuste
    var default_tit = 'Custom ARIMA(' + p + ',' + d + ',' + q + ')(' + P + ',' + D + ',' + Q + '): ' + src_label;
    var title_str = (main_tit !== '') ? main_tit : default_tit;

    if (has_xreg && newdf === '') {
        echo('custom_forecast <- NULL\n');
        echo('p <- ggplot2::autoplot(x_ts, series = "Actual") +\n');
        echo('     ggplot2::autolayer(stats::fitted(custom_model), series = "Fitted") +\n');
        echo('     ggplot2::theme_' + theme + '() + ggplot2::theme(legend.position = "bottom")\n');
    } else if (has_xreg && newdf !== '') {
        echo('if (!all(xreg_cols %in% colnames(' + newdf + '))) stop("Future Regressors Data Frame is missing required xreg columns.")\n');
        echo('newxreg_mat <- as.matrix(' + newdf + '[, xreg_cols, drop = FALSE])\n');
        echo('custom_forecast <- forecast::forecast(custom_model, xreg = newxreg_mat)\n');
        echo('p <- ggplot2::autoplot(custom_forecast) + ggplot2::theme_' + theme + '() + ggplot2::theme(legend.position = "bottom")\n');
    } else {
        echo('custom_forecast <- forecast::forecast(custom_model, h = ' + h + ')\n');
        echo('p <- ggplot2::autoplot(custom_forecast) + ggplot2::theme_' + theme + '() + ggplot2::theme(legend.position = "bottom")\n');
    }

    echo('p <- p + ggplot2::labs(title = "' + title_str + '"');
    if (x_tit !== '') echo(', x = "' + x_tit + '"');
    if (y_tit !== '') echo(', y = "' + y_tit + '"');
    echo(')\n');
  
}

function printout(is_preview){
	// read in variables from dialog


	// printout the results
	if(!is_preview) {
		new Header(i18n("2. Custom ARIMA & Dynamic Regression (xreg) results")).print();	
	}
    var w = getValue('cust_plot_w');
    var h = getValue('cust_plot_h');
    var res = getValue('cust_plot_res');

    if (typeof is_preview !== 'undefined' && is_preview) {
        echo('print(p)\n');
    }

    if (typeof is_preview === 'undefined' || !is_preview) {
        echo('rk.header("2. Custom ARIMA & Dynamic Regression Results")\n');

        echo('rk.graph.on(width = ' + w + ', height = ' + h + ', res = ' + res + ')\n');
        echo('print(p)\n');
        echo('rk.graph.off()\n\n');

        echo('rk.header("Model Parameters (Coefficients & p-values)", level = 3)\n');
        echo('rk.print(coef_table)\n');

        echo('rk.header("Goodness of Fit & Accuracy", level = 3)\n');
        echo('rk.print(fit_metrics)\n');

        echo('if (!is.null(custom_forecast)) {\n');
        echo('  rk.header("Forecasted Values", level = 3)\n');
        echo('  rk.print(as.data.frame(custom_forecast))\n');
        echo('} else {\n');
        echo('  rk.print("<i>Note: Model fitted with external regressors (xreg). Provide a Future Regressors Data Frame to generate h-step forecasts.</i>")\n');
        echo('}\n');

        if (getValue('cust_save_mod.active') || getValue('cust_save_fc.active') || getValue('cust_save_plot.active')) {
            echo('rk.print("<hr>")\n');
        }
        if (getValue('cust_save_mod.active')) {
            echo('rk.print(paste0("<b>ARIMA model saved as: </b><code>", "' + getValue('cust_save_mod') + '", "</code><br>"))\n');
        }
        if (getValue('cust_save_fc.active')) {
            echo('rk.print(paste0("<b>Forecast object saved as: </b><code>", "' + getValue('cust_save_fc') + '", "</code><br>"))\n');
        }
        if (getValue('cust_save_plot.active')) {
            echo('p$plot_env <- emptyenv()\n');
            echo('custom_plot <- p\n');
            echo('rk.print(paste0("<b>Plot object (ggplot2) saved as: </b><code>", "' + getValue('cust_save_plot') + '", "</code>"))\n');
        }
    }
  
	if(!is_preview) {
		//// save result object
		// read in saveobject variables
		var custSaveMod = getValue("cust_save_mod");
		var custSaveModActive = getValue("cust_save_mod.active");
		var custSaveModParent = getValue("cust_save_mod.parent");		var custSaveFc = getValue("cust_save_fc");
		var custSaveFcActive = getValue("cust_save_fc.active");
		var custSaveFcParent = getValue("cust_save_fc.parent");		var custSavePlot = getValue("cust_save_plot");
		var custSavePlotActive = getValue("cust_save_plot.active");
		var custSavePlotParent = getValue("cust_save_plot.parent");
		// assign object to chosen environment
		if(custSaveModActive) {
			echo(".GlobalEnv$" + custSaveMod + " <- custom_model\n");
		}
		if(custSaveFcActive) {
			echo(".GlobalEnv$" + custSaveFc + " <- custom_forecast\n");
		}
		if(custSavePlotActive) {
			echo(".GlobalEnv$" + custSavePlot + " <- custom_plot\n");
		}	
	}

}

