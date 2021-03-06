/*	FilterROIs by any combination of values in a results table
	v190604b - 1st public version. Minor cosmetic tweaks and added log stats: v190607
 */
 
macro "Filter ROIs by Feature Value"{
	requires("1.52a");
	// setBatchMode("true");
	saveSettings;
	if (nImages==0){
		showMessageWithCancel("No images open or the ROI Manager is empty...\n"
        + "Run demo? (Results Table and ROI Manager will be cleared)");
	    runDemo();
	}
	prefsNameKey = "ascMeasurementFiltersPrefs.";
	delimiter = "|";
	sigma = fromCharCode(0x03C3);
	run("Select None");
	if (roiManager("count")>0) roiManager("deselect");
	id = getImageID();	t=getTitle(); /* get id of image and title */
	checkForRoiManager(); /* macro requires that the objects are in the ROI manager */
	checkForResults(); /* macro requires that there are results to filter */
	nROIs = roiManager("count");
	nRES = nResults;
	getPixelSize(unit, pixelWidth, pixelHeight);
	menuLimit = 0.8 * screenHeight; /* used to limit menu size for small screens */
	if (nRES!=nROIs) restoreExit("Exit: Results table \(" + nRES + "\) and ROI Manager \(" + nROIs + "\) mismatch."); /* exit so that this ambiguity can be cleared up */
	if (nROIs<=1) restoreExit("Exit: ROI Manager has only \(" + nROIs + "\) entries."); /* exit so that this ambiguity can be cleared up */
	items = nROIs;
	setBatchMode(true);
	tN = stripKnownExtensionFromString(unCleanLabel(t)); /* File.nameWithoutExtension is specific to last opened file, also remove special characters that might cause issues saving file */
	measurements = split(Table.headings, "\t"); /* the tab specificity avoids problems with unusual column titles */
	if (measurements[0]==" " || measurements[0]=="") measurements = Array.deleteIndex(measurements, 0);
	mHdrs = lengthOf(measurements);
	mFilters = newArray(mHdrs);
	mFilters = Array.fill(mFilters, false);
	prefsNameKey = "ascMeasurementFiltersPrefs.MFilters";
	prefsMFilters = call("ij.Prefs.get", prefsNameKey, "None");
	clearEdge = false;
	if (prefsMFilters!="None") {
		lastUsedMFilters = split(prefsMFilters,delimiter);
		for (i=0; i<mHdrs; i++) {
			for (j=0; j<lastUsedMFilters.length; j++) {
				if (measurements[i]==lastUsedMFilters[j]) mFilters[i] = true; 
				if (lastUsedMFilters[j]=="clearEdgeOn") clearEdge = true;
			}
		}
	}
	checkboxGroupColumns = 5;
	checkboxGroupRows = round(mHdrs/checkboxGroupColumns)+1; /* Add +1 to make sure that there are enough cells */
	Dialog.create("Select ROI Filters");
		Dialog.addMessage("Select parameters to use for filtering image:\n" + tN);
		Dialog.addCheckboxGroup(checkboxGroupRows,checkboxGroupColumns,measurements,mFilters);
		Dialog.addCheckbox("Remove black edge objects, their ROIs and their table values?", clearEdge);
		Dialog.addMessage("The last filter\(s\) used will be stored in the user preferences");
		Dialog.addCheckbox("Reset preferences for next run \(none pre-selected next run\)?", false);
	Dialog.show();
	for (i=0; i<mHdrs; i++) mFilters[i] = Dialog.getCheckbox();
	mFiltered = newArray("");
	for (i=0; i<mHdrs; i++) if (mFilters[i]==true) mFiltered = Array.concat(mFiltered,measurements[i]);
	clearEdge = Dialog.getCheckbox();
	if (Dialog.getCheckbox()) call("ij.Prefs.set", prefsNameKey, "None");
	
	tNF = tN + "_filtered" ;
	run("Duplicate...", "title=[&tNF]");
	if (clearEdge) {
		removeEdgeObjects();
		for (i=items-1; i>-1; i--) {
			roiManager("select", i);
			getStatistics(null, mean, null, null, null);
			if (mean!=0) {
				roiManager("delete");
				Table.deleteRows(i, i);
			}
		}
		nROIs = roiManager("count");
		nRES = nResults;
		items = nROIs;
	}
	mFHdrs = mFiltered.length;
	if (mFHdrs==0) {
		close(tNF);
		restoreExit("No filters selected");
	}
	mMin = newArray(mFHdrs);
	mMax = newArray(mFHdrs);
	mMean = newArray(mFHdrs);
	mStdDev = newArray(mFHdrs);
	lnMean = newArray(mFHdrs);
	lnStdDev = newArray(mFHdrs);
	rangesCoded = newArray(mFHdrs);
	fMin = mMin;
	fMax = mMax;
	fROIs = Array.fill(newArray(items),true);
	if (mFiltered[0]==" " || mFiltered[0]=="") mFiltered = Array.deleteIndex(mFiltered, 0);
	mFHdrs = mFiltered.length;
	if (mFHdrs==0) restoreExit("No filters selected");
	for (i=0; i<mFHdrs; i++) {
		values = Table.getColumn(mFiltered[i]);
		Array.getStatistics(values, mMin[i], mMax[i], mMean[i], mStdDev[i]);
		lnValues = lnArray(values);
		Array.getStatistics(lnValues, null, null, lnMean[i], lnStdDev[i]); 
	}
	for (i=mFHdrs-1; i>-1; i--) {
		if(mMin[i]==mMax[i] || indexOf(mMax[i],"-")>0) {
			mFiltered = Array.deleteIndex(mFiltered, i);
			mMin = Array.deleteIndex(mMin, i);
			mMax = Array.deleteIndex(mMax, i);
			mMean = Array.deleteIndex(mMean, i);
			mStdDev = Array.deleteIndex(mStdDev, i);
		}
	}
	mFHdrs = mFiltered.length;
	if (mFHdrs>20) restoreExit ("Sorry, too little screen real estate for this many filters");
	if (mFHdrs==0) restoreExit("No filters selected");
	if (bitDepth()==24) colorChoice = newArray( "black", "blue", "cyan", "darkGray", "gray", "green", "lightGray", "magenta", "orange", "pink", "red", "white", "yellow");
	else colorChoice = newArray("white", "black", "lightGray", "gray", "darkGray");
	bgCol = getValue("color.background");
	Dialog.create("ROI Filter");
		Dialog.addMessage("A new image will be created with out-of-range objected cleared");
		Dialog.addMessage("Define in-range object parameters: min-max. Leave 'min' and//or 'max' if unchanged");
		for (i=0; i<mFHdrs; i++) {
			Dialog.addMessage(mFiltered[i]+ ":  mean = " + mMean[i] + ", min = "+ mMin[i] + ",   max = " + mMax[i] + ",   mean+" + sigma + " = " + mMean[i] + mStdDev[i] + ",   mean-" + sigma + " = " + mMean[i] - mStdDev[i] +"\n       ln:  mean = " + exp(lnMean[i]) + ", mean+" + sigma + " = " + exp(lnMean[i] + lnStdDev[i])+ ",   mean-" + sigma + " = " + exp(lnMean[i] - lnStdDev[i]));
			Dialog.addMessage("Use 's' and 'l' for " + sigma + " or ln-stat " + sigma + " deviations from mean,\ni.e. '2l-2l' is the ln-stats range of 2 " + sigma + " below to 2 " + sigma + " above the ln-stats mean.");
			Dialog.addString("Filtered range: ","min-max", 11);
		}
		Dialog.addChoice("Fill color for out-of-range \(background = " + bgCol + "\):", colorChoice, bgCol);
	Dialog.show;
		for (i=0; i<mFHdrs; i++)	rangesCoded[i] = Dialog.getString;
		run("Colors...", "background=" + Dialog.getChoice);
	for (i=mFHdrs-1; i>-1; i--) {
		if(rangesCoded[i]=="min-max") {
			mFiltered = Array.deleteIndex(mFiltered, i);
			fMin = Array.deleteIndex(fMin, i);
			fMax = Array.deleteIndex(fMax, i);
		}
	}
	mFHdrs = mFiltered.length;
	if (mFHdrs==0) restoreExit("No filters selected");
	metaString = "Filtered by ";
	for (i=0; i<mFHdrs; i++) {
		codedRange = split(rangesCoded[i], "-");
		if (codedRange[0]=="min") fMin[i] = mMin[i];
		else if (codedRange[0]=="s") fMin[i] = mMean[i]-mStdDev[i];
		else if (codedRange[0]=="2s") fMin[i] = mMean[i]-2*mStdDev[i];
		else if (codedRange[0]=="3s") fMin[i] = mMean[i]-3*mStdDev[i];
		else if (codedRange[0]=="l") fMin[i] = exp(lnMean[i]-lnStdDev[i]);
		else if (codedRange[0]=="2l") fMin[i] = exp(lnMean[i]-2*lnStdDev[i]);
		else if (codedRange[0]=="3l") fMin[i] = exp(lnMean[i]-3*lnStdDev[i]);
		else fMin[i] = parseFloat(codedRange[0]);
		if (codedRange[1]=="max") fMax[i] = mMax[i];
		else if (codedRange[0]=="s") fMax[i] = mMean[i]+mStdDev[i];
		else if (codedRange[0]=="2s") fMax[i] = mMean[i]+2*mStdDev[i];
		else if (codedRange[0]=="3s") fMax[i] = mMean[i]+3*mStdDev[i];
		else if (codedRange[0]=="l") fMax[i] = exp(lnMean[i]+lnStdDev[i]);
		else if (codedRange[0]=="2l") fMax[i] = exp(lnMean[i]+2*lnStdDev[i]);
		else if (codedRange[0]=="3l") fMax[i] = exp(lnMean[i]+3*lnStdDev[i]);
		else fMax[i] = parseFloat(codedRange[1]);
		values = Table.getColumn(mFiltered[i]);
		metaString += mFiltered[i] + ": " + fMin[i] + " - " + fMax[i] + "   ";
		for (j=0; j<items; j++) if(values[j]<fMin[i] || values[j]>fMax[i]) fROIs[j]=false;
	}
	Array.getStatistics(fROIs, null, anyTrue, null, null); 
	if (anyTrue==false) restoreExit("No ROIs within selected ranges");
	else {
		/* preference keys only updated on successful filter */
		mPrefsString = arrayToString(mFiltered,delimiter);
		if(clearEdge) mPrefsString += delimiter + "clearEdgeOn";
		else  mPrefsString += delimiter + "clearEdgeOff";
		call("ij.Prefs.set", prefsNameKey, mPrefsString);
	}
	for (i=0; i<items; i++){
		if(fROIs[i]==false) {
			roiManager("Select", i);
			run("Clear", "slice");
		}
	}
	metadata = getMetadata;
	metadata += metaString;
	setMetadata(metadata);
	restoreSettings;
	setBatchMode("exit & display");
	showStatus("Filter ROIs by Feature Values macro completed");
	beep(); wait(300); beep(); wait(300); beep();
	run("Collect Garbage");
}
	/*
		   ( 8(|)	( 8(|)	Functions	@@@@@:-)	@@@@@:-)
   */

	function arrayToString(array,delimiters){
		/* 1st version April 2019 PJL */
		for (i=0; i<array.length; i++){
			if (i==0) string = "" + array[0];
			else  string = string + delimiters + array[i];
		}
		return string;
	}
	function checkForPlugin(pluginName) {
		/* v161102 changed to true-false */
		var pluginCheck = false, subFolderCount = 0;
		if (getDirectory("plugins") == "") restoreExit("Failure to find any plugins!");
		else pluginDir = getDirectory("plugins");
		if (!endsWith(pluginName, ".jar")) pluginName = pluginName + ".jar";
		if (File.exists(pluginDir + pluginName)) {
				pluginCheck = true;
				showStatus(pluginName + "found in: "  + pluginDir);
		}
		else {
			pluginList = getFileList(pluginDir);
			subFolderList = newArray(lengthOf(pluginList));
			for (i=0; i<lengthOf(pluginList); i++) {
				if (endsWith(pluginList[i], "/")) {
					subFolderList[subFolderCount] = pluginList[i];
					subFolderCount = subFolderCount +1;
				}
			}
			subFolderList = Array.slice(subFolderList, 0, subFolderCount);
			for (i=0; i<lengthOf(subFolderList); i++) {
				if (File.exists(pluginDir + subFolderList[i] +  "\\" + pluginName)) {
					pluginCheck = true;
					showStatus(pluginName + " found in: " + pluginDir + subFolderList[i]);
					i = lengthOf(subFolderList);
				}
			}
		}
		return pluginCheck;
	}
	function checkForResults() {
		nROIs = roiManager("count");
		nRES = nResults;
		if (nRES==0)	{
			Dialog.create("No Results to Work With");
			Dialog.addCheckbox("Run Analyze-particles to generate table?", true);
			Dialog.addMessage("This macro requires a Results table to analyze.\n \nThere are   " + nRES +"   results.\nThere are    " + nROIs +"   ROIs.");
			Dialog.show();
			analyzeNow = Dialog.getCheckbox(); /* If (analyzeNow==true), ImageJ Analyze Particles will be performed, otherwise exit */
			if (analyzeNow==true) {
				if (roiManager("count")!=0) {
					roiManager("deselect")
					roiManager("delete"); 
				}
				setOption("BlackBackground", false);
				run("Analyze Particles..."); /* Let user select settings */
			}
			else restoreExit("Goodbye, your previous setting will be restored.");
		}
	}
	function checkForRoiManager() {
		/* v161109 adds the return of the updated ROI count and also adds dialog if there are already entries just in case . .
			v180104 only asks about ROIs if there is a mismatch with the results */
		nROIs = roiManager("count");
		nRES = nResults; /* Used to check for ROIs:Results mismatch */
		if(nROIs==0) runAnalyze = true; /* Assumes that ROIs are required and that is why this function is being called */
		else if(nROIs!=nRES) runAnalyze = getBoolean("There are " + nRES + " results and " + nROIs + " ROIs; do you want to clear the ROI manager and reanalyze?");
		else runAnalyze = false;
		if (runAnalyze) {
			roiManager("reset");
			Dialog.create("Analysis check");
			Dialog.addCheckbox("Run Analyze-particles to generate new roiManager values?", true);
			Dialog.addMessage("This macro requires that all objects have been loaded into the ROI manager.\n \nThere are   " + nRES +"   results.\nThere are   " + nROIs +"   ROIs.");
			Dialog.show();
			analyzeNow = Dialog.getCheckbox();
			if (analyzeNow) {
				setOption("BlackBackground", false);
				if (nResults==0)
					run("Analyze Particles...", "display add");
				else run("Analyze Particles..."); /* Let user select settings */
				if (nResults!=roiManager("count"))
					restoreExit("Results and ROI Manager counts do not match!");
			}
			else restoreExit("Goodbye, your previous setting will be restored.");
		}
		return roiManager("count"); /* Returns the new count of entries */
	}
	function lnArray(arrayName) {				  
	/* 1st version: v180318 */
	outputArray = Array.copy(arrayName);
	for (i=0; i<lengthOf(arrayName); i++)
		outputArray[i] = log(arrayName[i]);
	return outputArray;
	}
	function removeEdgeObjects(){
	/*	Remove black edge objects without using Analyze Particles
	Peter J. Lee  National High Magnetic Field Laboratory
	Requires the versatile wand tool: https://imagej.nih.gov/ij/plugins/versatile-wand-tool/index.html by Michael Schmid
	as built in wand does not select edge objects
	1st version v190604
	v190605 This version uses Gabriel Landini's morphology plugin if available
	*/
		if (checkForPlugin("morphology_collection.jar")) run("BinaryKillBorders ", "top right bottom left");
		else {
			if (!checkForPlugin("Versatile_Wand_Tool.java") && !checkForPlugin("versatile_wand_tool.jar") && !checkForPlugin("Versatile_Wand_Tool.jar")) restoreExit("Versatile wand tool required");
			run("Select None");
			originalBGCol = getValue("color.background");
			print(originalBGCol);
			cWidth = getWidth()+2; cHeight = getHeight()+2;
			run("Canvas Size...", "width=&cWidth height=&cHeight position=Center");
			setColor("black");
			drawRect(0, 0, cWidth, cHeight);
			call("Versatile_Wand_Tool.doWand", 0, 0, 0.0, 0.0, 0.0, "8-connected");
			run("Colors...", "background=white");
			run("Clear", "slice");
			setBackgroundColor(originalBGCol); /* Return background to original color */
			makeRectangle(1, 1, cWidth-2, cHeight-2);
			run("Crop");
		}
		showStatus("Remove_Edge_Objects function complete");
	}
	function restoreExit(message){ /* Make a clean exit from a macro, restoring previous settings */
		/* 9/9/2017 added Garbage clean up suggested by Luc LaLonde - LBNL */
		restoreSettings(); /* Restore previous settings before exiting */
		setBatchMode("exit & display"); /* Probably not necessary if exiting gracefully but otherwise harmless */
		run("Collect Garbage");
		exit(message);
	}
	function runDemo() { /* Generates standard imageJ demo blob analysis */
	/* v180104 */
	    run("Blobs (25K)");
		run("Auto Threshold", "method=Default");
		run("Convert to Mask");
		run("Set Scale...", "distance=10 known=1 unit=um"); /* Add an arbitrary scale to demonstrate unit usage. */
		run("Analyze Particles...", "display exclude clear add");
		resetThreshold();
		if(is("Inverting LUT")) run("Invert LUT");
	}
	function stripKnownExtensionFromString(string) {
		if (lastIndexOf(string, ".")!=-1) {
			knownExt = newArray("tif", "tiff", "TIF", "TIFF", "png", "PNG", "GIF", "gif", "jpg", "JPG", "jpeg", "JPEG", "jp2", "JP2", "txt", "TXT", "csv", "CSV");
			for (i=0; i<knownExt.length; i++) {
				index = lastIndexOf(string, "." + knownExt[i]);
				if (index>=(lengthOf(string)-(lengthOf(knownExt[i])+1))) string = substring(string, 0, index);
			}
		}
		return string;
	}
	function unCleanLabel(string) {
	/* v161104 This function replaces special characters with standard characters for file system compatible filenames
	+ 041117 to remove spaces as well */
		string= replace(string, fromCharCode(178), "\\^2"); /* superscript 2 */
		string= replace(string, fromCharCode(179), "\\^3"); /* superscript 3 UTF-16 (decimal) */
		string= replace(string, fromCharCode(0xFE63) + fromCharCode(185), "\\^-1"); /* Small hypen substituted for superscript minus as 0x207B does not display in table */
		string= replace(string, fromCharCode(0xFE63) + fromCharCode(178), "\\^-2"); /* Small hypen substituted for superscript minus as 0x207B does not display in table */
		string= replace(string, fromCharCode(181), "u"); /* micron units */
		string= replace(string, fromCharCode(197), "Angstrom"); /* �ngstr�m unit symbol */
		string= replace(string, fromCharCode(0x2009) + fromCharCode(0x00B0), "deg"); /* replace thin spaces degrees combination */
		string= replace(string, fromCharCode(0x2009), "_"); /* Replace thin spaces  */
		string= replace(string, " ", "_"); /* Replace spaces - these can be a problem with image combination */
		string= replace(string, "_\\+", "\\+"); /* Clean up autofilenames */
		string= replace(string, "\\+\\+", "\\+"); /* Clean up autofilenames */
		string= replace(string, "__", "_"); /* Clean up autofilenames */
		return string;
	}