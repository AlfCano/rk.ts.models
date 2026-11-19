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
        echo('applied_model <- ' + mod + '\n');
        echo('if (!is.null(applied_model$xreg)) stop("Models with xreg require Custom ARIMA to supply newxreg.")\n');
        echo('applied_forecast <- forecast::forecast(applied_model, h = ' + h + ')\n');
    } else {
        echo('if (!is.null(' + mod + '$xreg)) stop("Models fitted with external regressors (xreg) require Custom ARIMA to supply new xreg values.")\n');
        echo('new_y <- ' + new_ts + '\n');
        echo('if (anyNA(new_y)) stop("New time series contains NAs. Please impute missing values first.")\n\n');

        echo('if (inherits(' + mod + ', "ets")) {\n');
        if (reest === 'keep') {
            echo('  applied_model <- forecast::ets(new_y, model = ' + mod + ', use.initial.values = TRUE)\n');
        } else {
            echo('  m_str <- paste(' + mod + '$components[1:3], collapse = "")\n');
            echo('  m_dmp <- isTRUE(as.logical(' + mod + '$components[4]))\n');
            echo('  applied_model <- forecast::ets(new_y, model = m_str, damped = m_dmp, lambda = ' + mod + '$lambda)\n');
        }
        echo('} else if (inherits(' + mod + ', "Arima")) {\n');
        if (reest === 'keep') {
            echo('  applied_model <- forecast::Arima(new_y, model = ' + mod + ')\n');
        } else {
            echo('  ord <- forecast::arimaorder(' + mod + ')\n');
            echo('  inc_c <- any(c("drift", "intercept") %in% names(stats::coef(' + mod + ')))\n');
            echo('  if (length(ord) == 7) {\n');
            echo('    applied_model <- forecast::Arima(new_y, order = ord[1:3], seasonal = list(order = ord[4:6], period = ord[7]), include.constant = inc_c, lambda = ' + mod + '$lambda)\n');
            echo('  } else {\n');
            echo('    applied_model <- forecast::Arima(new_y, order = ord[1:3], include.constant = inc_c, lambda = ' + mod + '$lambda)\n');
            echo('  }\n');
        }
        echo('} else {\n');
        echo('  stop("Unsupported model class. Please provide an Arima or ets object.")\n');
        echo('}\n');
        echo('applied_forecast <- forecast::forecast(applied_model, h = ' + h + ')\n');
    }
    echo('\n');

    echo('acc_app <- as.data.frame(forecast::accuracy(applied_model))\n\n');

    var title_str = (main_tit !== '') ? main_tit : 'Applied Forecast (' + mod + ')';
    echo('p <- ggplot2::autoplot(applied_forecast) + ggplot2::theme_' + theme + '() +\n');
    echo('     ggplot2::labs(title = "' + title_str + '"');
    if (x_tit !== '') echo(', x = "' + x_tit + '"');
    if (y_tit !== '') echo(', y = "' + y_tit + '"');
    echo(') + ggplot2::theme(legend.position = "bottom")\n');
  
}

function printout(is_preview){
	// read in variables from dialog


	// printout the results
	if(!is_preview) {
		new Header(i18n("3. Apply Saved Model results")).print();	
	}
    var w = getValue('app_plot_w');
    var h = getValue('app_plot_h');
    var res = getValue('app_plot_res');

    if (typeof is_preview !== 'undefined' && is_preview) {
        echo('print(p)\n');
    }

    if (typeof is_preview === 'undefined' || !is_preview) {
        echo('rk.header("3. Apply Saved Model Results")\n');

        echo('rk.graph.on(width = ' + w + ', height = ' + h + ', res = ' + res + ')\n');
        echo('print(p)\n');
        echo('rk.graph.off()\n\n');

        echo('rk.header("Applied Model Summary", level = 3)\n');
        echo('rk.print(summary(applied_model))\n');

        echo('rk.header("Accuracy Metrics on Target Series", level = 3)\n');
        echo('rk.print(acc_app)\n');

        echo('rk.header("Forecasted Values", level = 3)\n');
        echo('rk.print(as.data.frame(applied_forecast))\n');

        if (getValue('app_save_fc.active') || getValue('app_save_mod.active') || getValue('app_save_plot.active')) {
            echo('rk.print("<hr>")\n');
        }
        if (getValue('app_save_fc.active')) {
            echo('rk.print(paste0("<b>Applied forecast saved as: </b><code>", "' + getValue('app_save_fc') + '", "</code><br>"))\n');
        }
        if (getValue('app_save_mod.active')) {
            echo('rk.print(paste0("<b>Applied model saved as: </b><code>", "' + getValue('app_save_mod') + '", "</code><br>"))\n');
        }
        if (getValue('app_save_plot.active')) {
            echo('p$plot_env <- emptyenv()\n');
            echo('applied_plot <- p\n');
            echo('rk.print(paste0("<b>Plot object (ggplot2) saved as: </b><code>", "' + getValue('app_save_plot') + '", "</code>"))\n');
        }
    }
  
	if(!is_preview) {
		//// save result object
		// read in saveobject variables
		var appSaveFc = getValue("app_save_fc");
		var appSaveFcActive = getValue("app_save_fc.active");
		var appSaveFcParent = getValue("app_save_fc.parent");		var appSaveMod = getValue("app_save_mod");
		var appSaveModActive = getValue("app_save_mod.active");
		var appSaveModParent = getValue("app_save_mod.parent");		var appSavePlot = getValue("app_save_plot");
		var appSavePlotActive = getValue("app_save_plot.active");
		var appSavePlotParent = getValue("app_save_plot.parent");
		// assign object to chosen environment
		if(appSaveFcActive) {
			echo(".GlobalEnv$" + appSaveFc + " <- applied_forecast\n");
		}
		if(appSaveModActive) {
			echo(".GlobalEnv$" + appSaveMod + " <- applied_model\n");
		}
		if(appSavePlotActive) {
			echo(".GlobalEnv$" + appSavePlot + " <- applied_plot\n");
		}	
	}

}

