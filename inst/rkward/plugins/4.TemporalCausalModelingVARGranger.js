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
		echo("if(!base::require(vars)){stop(" + i18n("Preview not available, because package vars is not installed or cannot be loaded.") + ")}\n");
	} else {
		echo("require(vars)\n");
	}	if(is_preview) {
		echo("if(!base::require(stats)){stop(" + i18n("Preview not available, because package stats is not installed or cannot be loaded.") + ")}\n");
	} else {
		echo("require(stats)\n");
	}
}

function calculate(is_preview){
	// read in variables from dialog


	// the R code to be evaluated

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

        var cols_arr = cols_raw.split('\n').map(parseVar).filter(Boolean);
        if (cols_arr.length < 2) {
            echo('stop("Please select at least 2 numeric variables for a VAR model.")\n');
        } else {
            var cols_str = 'c(' + cols_arr.map(function(v){ return '"' + v + '"'; }).join(', ') + ')';
            echo('mts_data <- stats::ts(as.matrix(' + df + '[, ' + cols_str + ', drop = FALSE]), frequency = ' + freq + ', start = c(' + yr + ', ' + pd + '))\n');
        }
    } else {
        var mts_obj = getValue('var_mts');
        echo('mts_data <- ' + mts_obj + '\n');
        echo('if (NCOL(mts_data) < 2) stop("Multivariate time series must have at least 2 columns.")\n');
    }

    echo('mts_data <- stats::na.omit(mts_data)\n\n');

    echo('sel_tbl <- data.frame()\n');
    if (lag_mode === 'auto') {
        echo('sel_res <- vars::VARselect(mts_data, lag.max = ' + lag_max + ', type = "' + det_type + '")\n');
        echo('sel_tbl <- as.data.frame(t(sel_res$selection))\n');
        echo('best_p <- as.numeric(sel_res$selection["' + ic + '"])\n');
        echo('if (is.na(best_p) || best_p < 1) best_p <- 1\n');
        echo('var_model <- vars::VAR(mts_data, p = best_p, type = "' + det_type + '")\n');
        echo('var_model$call$p <- best_p\n\n'); // <-- AGREGAR ESTA LÍNEA
    } else {
        echo('var_model <- vars::VAR(mts_data, p = ' + lag_p + ', type = "' + det_type + '")\n\n');
    }

    echo('var_forecast <- stats::predict(var_model, n.ahead = ' + h + ', ci = 0.95)\n\n');

    // Causalidad de Granger para todas las variables del sistema
    echo('granger_df <- data.frame()\n');
    if (do_granger) {
        echo('v_names <- colnames(mts_data)\n');
        echo('for (v in v_names) {\n');
        echo('  g_res <- tryCatch(vars::causality(var_model, cause = v)$Granger, error = function(e) NULL)\n');
        echo('  if (!is.null(g_res)) {\n');
        echo('    eff <- paste(setdiff(v_names, v), collapse = ", ")\n');
        echo('    pval <- as.numeric(g_res$p.value)\n');
        echo('    granger_df <- rbind(granger_df, data.frame(\n');
        echo('      Cause = v, Effect = eff,\n');
        echo('      F_Stat = round(as.numeric(g_res$statistic), 4),\n');
        echo('      df1 = as.numeric(g_res$parameter[1]), df2 = as.numeric(g_res$parameter[2]),\n');
        echo('      P_Value = round(pval, 4),\n');
        echo('      Conclusion = ifelse(pval < 0.05, "Significant (Granger-causes)", "Not Significant")\n');
        echo('    ))\n');
        echo('  }\n');
        echo('}\n');
    }
    echo('\n');

    // Prueba de autocorrelación multivariada en residuos
    echo('var_diag_tbl <- tryCatch({\n');
    echo('  pt <- vars::serial.test(var_model, lags.pt = min(12, floor(nrow(mts_data) / 3)), type = "PT.asymptotic")$serial\n');
    echo('  data.frame(Test = "Portmanteau (VAR Residuals)", Chi_Sq = round(as.numeric(pt$statistic), 4), df = as.numeric(pt$parameter), P_Value = round(pt$p.value, 4), Conclusion = ifelse(pt$p.value >= 0.05, "No residual autocorrelation", "Autocorrelation remains (Try higher p)"))\n');
    echo('}, error = function(e) data.frame())\n');
  
}

function printout(is_preview){
	// read in variables from dialog


	// printout the results
	if(!is_preview) {
		new Header(i18n("4. Temporal Causal Modeling (VAR & Granger) results")).print();	
	}
    var w = getValue('var_plot_w');
    var h = getValue('var_plot_h');
    var res = getValue('var_plot_res');
    var h_fc = getValue('var_h');
    var do_irf = getValue('var_chk_irf') === '1';

    if (typeof is_preview !== 'undefined' && is_preview) {
        echo('grDevices::devAskNewPage(FALSE)\n');
        echo('plot(var_forecast, plot.type = "multiple")\n');
    }

    if (typeof is_preview === 'undefined' || !is_preview) {
        echo('rk.header("4. Temporal Causal Modeling (VAR & Granger)")\n');

        echo('rk.graph.on(width = ' + w + ', height = ' + h + ', res = ' + res + ')\n');
        echo('grDevices::devAskNewPage(FALSE)\n');
        echo('plot(var_forecast, plot.type = "multiple")\n');
        if (getValue('var_save_plot.active')) {
            echo('var_plot <- grDevices::recordPlot()\n');
        }
        echo('rk.graph.off()\n\n');

        echo('if (nrow(sel_tbl) > 0) {\n');
        echo('  rk.header("Optimal Lag Selection (VARselect)", level = 3)\n');
        echo('  rk.print(sel_tbl)\n');
        echo('}\n');

        echo('if (nrow(granger_df) > 0) {\n');
        echo('  rk.header("Granger Causality Tests", level = 3)\n');
        echo('  rk.print(granger_df)\n');
        echo('}\n');

        echo('if (nrow(var_diag_tbl) > 0) {\n');
        echo('  rk.header("Residual Serial Correlation Test", level = 3)\n');
        echo('  rk.print(var_diag_tbl)\n');
        echo('}\n');

        if (do_irf) {
            echo('rk.header("Impulse Response Functions (IRF)", level = 3)\n');
            echo('for (imp_v in colnames(mts_data)) {\n');
            echo('  irf_single <- vars::irf(var_model, impulse = imp_v, n.ahead = ' + h_fc + ', boot = TRUE)\n');
            echo('  rk.graph.on(width = ' + w + ', height = ' + h + ', res = ' + res + ')\n');
            echo('  grDevices::devAskNewPage(FALSE)\n');
            echo('  plot(irf_single)\n');
            echo('  rk.graph.off()\n');
            echo('}\n\n');
        }

        echo('rk.header("VAR Model Forecasts", level = 3)\n');
        echo('for (v_nm in names(var_forecast$fcst)) {\n');
        echo('  rk.header(paste("Series:", v_nm), level = 4)\n');
        echo('  rk.print(as.data.frame(var_forecast$fcst[[v_nm]]))\n');
        echo('}\n');

        if (getValue('var_save_mod.active') || getValue('var_save_fc.active') || getValue('var_save_plot.active')) {
            echo('rk.print("<hr>")\n');
        }
        if (getValue('var_save_mod.active')) {
            echo('rk.print(paste0("<b>VAR model saved as: </b><code>", "' + getValue('var_save_mod') + '", "</code><br>"))\n');
        }
        if (getValue('var_save_fc.active')) {
            echo('rk.print(paste0("<b>VAR forecast saved as: </b><code>", "' + getValue('var_save_fc') + '", "</code><br>"))\n');
        }
        if (getValue('var_save_plot.active')) {
            echo('rk.print(paste0("<b>Plot object (recorded) saved as: </b><code>", "' + getValue('var_save_plot') + '", "</code>"))\n');
        }
    }
  
	if(!is_preview) {
		//// save result object
		// read in saveobject variables
		var varSaveMod = getValue("var_save_mod");
		var varSaveModActive = getValue("var_save_mod.active");
		var varSaveModParent = getValue("var_save_mod.parent");		var varSaveFc = getValue("var_save_fc");
		var varSaveFcActive = getValue("var_save_fc.active");
		var varSaveFcParent = getValue("var_save_fc.parent");		var varSavePlot = getValue("var_save_plot");
		var varSavePlotActive = getValue("var_save_plot.active");
		var varSavePlotParent = getValue("var_save_plot.parent");
		// assign object to chosen environment
		if(varSaveModActive) {
			echo(".GlobalEnv$" + varSaveMod + " <- var_model\n");
		}
		if(varSaveFcActive) {
			echo(".GlobalEnv$" + varSaveFc + " <- var_forecast\n");
		}
		if(varSavePlotActive) {
			echo(".GlobalEnv$" + varSavePlot + " <- var_plot\n");
		}	
	}

}

