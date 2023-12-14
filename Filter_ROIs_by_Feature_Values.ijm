/*	FilterROIs by any combination of values in a results table
	v190604b - 1st public version. Minor cosmetic tweaks and added log stats: v190607
	v211025 Updated functions
	v211104: Updated stripKnownExtensionFromString function    211112, 220616, 220815, 220818: Updated functions f7: updated function stripKnownExtensionFromString. F10: Updated checkForRoiManager function.
 */
 
macro "Filter ROIs by Feature Value"{
	macroL = "ASC-Filter_ROIs_by_Feature_Values_v211112-f10.ijm";
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
	nROIs = checkForRoiManager(); /* macro requires that the objects are in the ROI manager */
	checkForResults(); /* macro requires that there are results to filter */
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
		Dialog.addMessage("Macro version: " + macroL);
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
	function arrayToString(array,delimiter){
		/* 1st version April 2019 PJL
			v190722 Modified to handle zero length array
			v201215 += stopped working so this shortcut has been replaced */
		for (i=0; i<array.length; i++){
			if (i==0) string = "" + array[0];
			else  string = string + delimiter + array[i];
		}
		return string;
	}
	function checkForPlugin(pluginName) {
		/* v161102 changed to true-false
			v180831 some cleanup
			v210429 Expandable array version
			v220510 Looks for both class and jar if no extension is given
			v220818 Mystery issue fixed, no longer requires restoreExit	*/
		pluginCheck = false;
		if (getDirectory("plugins") == "") print("Failure to find any plugins!");
		else {
			pluginDir = getDirectory("plugins");
			if (lastIndexOf(pluginName,".")==pluginName.length-1) pluginName = substring(pluginName,0,pluginName.length-1);
			pExts = newArray(".jar",".class");
			knownExt = false;
			for (j=0; j<lengthOf(pExts); j++) if(endsWith(pluginName,pExts[j])) knownExt = true;
			pluginNameO = pluginName;
			for (j=0; j<lengthOf(pExts) && !pluginCheck; j++){
				if (!knownExt) pluginName = pluginName + pExts[j];
				if (File.exists(pluginDir + pluginName)) {
					pluginCheck = true;
					showStatus(pluginName + "found in: "  + pluginDir);
				}
				else {
					pluginList = getFileList(pluginDir);
					subFolderList = newArray;
					for (i=0,subFolderCount=0; i<lengthOf(pluginList); i++) {
						if (endsWith(pluginList[i], "/")) {
							subFolderList[subFolderCount] = pluginList[i];
							subFolderCount++;
						}
					}
					for (i=0; i<lengthOf(subFolderList); i++) {
						if (File.exists(pluginDir + subFolderList[i] +  "\\" + pluginName)) {
							pluginCheck = true;
							showStatus(pluginName + " found in: " + pluginDir + subFolderList[i]);
							i = lengthOf(subFolderList);
						}
					}
				}
			}
		}
		return pluginCheck;
	}
	function checkForResults() {
	/* NOTE: REQUIRES ASC restoreExit function which requires previous run of saveSettings */
		nROIs = roiManager("count");
		nRes = nResults;
		if (nRes==0)	{
			Dialog.create("No Results to Work With");
			Dialog.addCheckbox("Run Analyze-particles to generate table?", true);
			Dialog.addMessage("This macro requires a Results table to analyze.\n \nThere are   " + nRes +"   results.\nThere are    " + nROIs +"   ROIs.");
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
			v180104 only asks about ROIs if there is a mismatch with the results
			v190628 adds option to import saved ROI set
			v210428	include thresholding if necessary and color check
			NOTE: Requires ASC restoreExit function, which assumes that saveSettings has been run at the beginning of the macro
			*/
		functionL = "checkForRoiManager_v210428";
		nROIs = roiManager("count");
		nRes = nResults; /* Used to check for ROIs:Results mismatch */
		if(nROIs==0 || nROIs!=nRes){
			Dialog.create("ROI options: " + functionL);
				Dialog.addMessage("This macro requires that all objects have been loaded into the ROI manager.\n \nThere are   " + nRes +"   results.\nThere are   " + nROIs +"   ROIs.\nDo you want to:");
				if(nROIs==0) Dialog.addCheckbox("Import a saved ROI list",false);
				else Dialog.addCheckbox("Replace the current ROI list with a saved ROI list",false);
				if(nRes==0) Dialog.addCheckbox("Import a Results Table \(csv\) file",false);
				else Dialog.addCheckbox("Clear Results Table and import saved csv",false);
				Dialog.addCheckbox("Clear ROI list and Results Table and reanalyze \(overrides above selections\)",true);
				if (!is("binary")) Dialog.addMessage("The active image is not binary, so it may require thresholding before analysis");
				Dialog.addCheckbox("Get me out of here, I am having second thoughts . . .",false);
			Dialog.show();
				importROI = Dialog.getCheckbox;
				importResults = Dialog.getCheckbox;
				runAnalyze = Dialog.getCheckbox;
				if (Dialog.getCheckbox) restoreExit("Sorry this did not work out for you.");
			if (runAnalyze) {
				if (!is("binary")){
					if (is("grayscale") && bitDepth()>8){
						proceed = getBoolean("Image is grayscale but not 8-bit, convert it to 8-bit?", "Convert for thresholding", "Get me out of here");
						if (proceed) run("8-bit");
						else restoreExit("Goodbye, perhaps analyze first?");
					}
					if (bitDepth()==24){
						colorThreshold = getBoolean("Active image is RGB, so analysis requires thresholding", "Color Threshold", "Convert to 8-bit and threshold");
						if (colorThreshold) run("Color Threshold...");
						else run("8-bit");
					}
					if (!is("binary")){
						/* Quick-n-dirty threshold if not previously thresholded */
						getThreshold(t1,t2);  
						if (t1==-1)  {
							run("Auto Threshold", "method=Default");
							setOption("BlackBackground", false);
							run("Make Binary");
						}
						if (is("Inverting LUT"))  {
							trueLUT = getBoolean("The LUT appears to be inverted, do you want the true LUT?", "Yes Please", "No Thanks");
							if (trueLUT) run("Invert LUT");
						}
					}
				}
				if (isOpen("ROI Manager"))	roiManager("reset");
				setOption("BlackBackground", false);
				if (isOpen("Results")) {
					selectWindow("Results");
					run("Close");
				}
				run("Analyze Particles..."); /* Let user select settings */
				if (nResults!=roiManager("count"))
					restoreExit("Results and ROI Manager counts do not match!");
			}
			else {
				if (importROI) {
					if (isOpen("ROI Manager"))	roiManager("reset");
					msg = "Import ROI set \(zip file\), click \"OK\" to continue to file chooser";
					showMessage(msg);
					roiManager("Open", "");
				}
				if (importResults){
					if (isOpen("Results")) {
						selectWindow("Results");
						run("Close");
					}
					msg = "Import Results Table, click \"OK\" to continue to file chooser";
					showMessage(msg);
					open("");
					Table.rename(Table.title, "Results");
				}
			}
		}
		nROIs = roiManager("count");
		nRes = nResults; /* Used to check for ROIs:Results mismatch */
		if(nROIs==0 || nROIs!=nRes)
			restoreExit("Goodbye, your previous setting will be restored.");
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
	v190605 This version uses Gabriel Landini's morphology plugin if available.
	v200102 Removed unnecessary print command.
	*/
		if (checkForPlugin("morphology_collection.jar")) run("BinaryKillBorders ", "top right bottom left");
		else {
			if (!checkForPlugin("Versatile_Wand_Tool.java") && !checkForPlugin("versatile_wand_tool.jar") && !checkForPlugin("Versatile_Wand_Tool.jar")) restoreExit("Versatile wand tool required");
			run("Select None");
			originalBGCol = getValue("color.background");
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
		/*	Note: Do not use on path as it may change the directory names
		v210924: Tries to make sure string stays as string.	v211014: Adds some additional cleanup.	v211025: fixes multiple 'known's issue.	v211101: Added ".Ext_" removal.
		v211104: Restricts cleanup to end of string to reduce risk of corrupting path.	v211112: Tries to fix trapped extension before channel listing. Adds xlsx extension.
		v220615: Tries to fix the fix for the trapped extensions ...	v230504: Protects directory path if included in string. Only removes doubled spaces and lines.
		v230505: Unwanted dupes replaced by unusefulCombos.	v230607: Quick fix for infinite loop on one of while statements.
		v230614: Added AVI.	v230905: Better fix for infinite loop. v230914: Added BMP and "_transp" and rearranged
		*/
		fS = File.separator;
		string = "" + string;
		protectedPathEnd = lastIndexOf(string,fS)+1;
		if (protectedPathEnd>0){
			protectedPath = substring(string,0,protectedPathEnd);
			string = substring(string,protectedPathEnd);
		}
		unusefulCombos = newArray("-", "_"," ");
		for (i=0; i<lengthOf(unusefulCombos); i++){
			for (j=0; j<lengthOf(unusefulCombos); j++){
				combo = unusefulCombos[i] + unusefulCombos[j];
				while (indexOf(string,combo)>=0) string = replace(string,combo,unusefulCombos[i]);
			}
		}
		if (lastIndexOf(string, ".")>0 || lastIndexOf(string, "_lzw")>0) {
			knownExts = newArray(".avi", ".csv", ".bmp", ".dsx", ".gif", ".jpg", ".jpeg", ".jp2", ".png", ".tif", ".txt", ".xlsx");
			knownExts = Array.concat(knownExts,knownExts,"_transp","_lzw");
			kEL = knownExts.length;
			for (i=0; i<kEL/2; i++) knownExts[i] = toUpperCase(knownExts[i]);
			chanLabels = newArray(" \(red\)"," \(green\)"," \(blue\)","\(red\)","\(green\)","\(blue\)");
			for (i=0,k=0; i<kEL; i++) {
				for (j=0; j<chanLabels.length; j++){ /* Looking for channel-label-trapped extensions */
					iChanLabels = lastIndexOf(string, chanLabels[j])-1;
					if (iChanLabels>0){
						preChan = substring(string,0,iChanLabels);
						postChan = substring(string,iChanLabels);
						while (indexOf(preChan,knownExts[i])>0){
							preChan = replace(preChan,knownExts[i],"");
							string =  preChan + postChan;
						}
					}
				}
				while (endsWith(string,knownExts[i])) string = "" + substring(string, 0, lastIndexOf(string, knownExts[i]));
			}
		}
		unwantedSuffixes = newArray(" ", "_","-");
		for (i=0; i<unwantedSuffixes.length; i++){
			while (endsWith(string,unwantedSuffixes[i])) string = substring(string,0,string.length-lengthOf(unwantedSuffixes[i])); /* cleanup previous suffix */
		}
		if (protectedPathEnd>0){
			if(!endsWith(protectedPath,fS)) protectedPath += fS;
			string = protectedPath + string;
		}
		return string;
	}
	function unCleanLabel(string) {
	/* v161104 This function replaces special characters with standard characters for file system compatible filenames.
	+ 041117b to remove spaces as well.
	+ v220126 added getInfo("micrometer.abbreviation").
	+ v220128 add loops that allow removal of multiple duplication.
	+ v220131 fixed so that suffix cleanup works even if extensions are included.
	+ v220616 Minor index range fix that does not seem to have an impact if macro is working as planned. v220715 added 8-bit to unwanted dupes. v220812 minor changes to micron and Ångström handling
	+ v231005 Replaced superscript abbreviations that did not work.
	*/
		/* Remove bad characters */
		string = string.replace(fromCharCode(178), "sup2"); /* superscript 2 */
		string = string.replace(fromCharCode(179), "sup3"); /* superscript 3 UTF-16 (decimal) */
		string = string.replace(fromCharCode(0xFE63) + fromCharCode(185), "sup-1"); /* Small hyphen substituted for superscript minus as 0x207B does not display in table */
		string = string.replace(fromCharCode(0xFE63) + fromCharCode(178), "sup-2"); /* Small hyphen substituted for superscript minus as 0x207B does not display in table */
		string = string.replace(fromCharCode(181)+"m", "um"); /* micron units */
		string = string.replace(getInfo("micrometer.abbreviation"), "um"); /* micron units */
		string = string.replace(fromCharCode(197), "Angstrom"); /* Ångström unit symbol */
		string = string.replace(fromCharCode(0x212B), "Angstrom"); /* the other Ångström unit symbol */
		string = string.replace(fromCharCode(0x2009) + fromCharCode(0x00B0), "deg"); /* replace thin spaces degrees combination */
		string = string.replace(fromCharCode(0x2009), "_"); /* Replace thin spaces  */
		string = string.replace("%", "pc"); /* % causes issues with html listing */
		string = string.replace(" ", "_"); /* Replace spaces - these can be a problem with image combination */
		/* Remove duplicate strings */
		unwantedDupes = newArray("8bit","8-bit","lzw");
		for (i=0; i<lengthOf(unwantedDupes); i++){
			iLast = lastIndexOf(string,unwantedDupes[i]);
			iFirst = indexOf(string,unwantedDupes[i]);
			if (iFirst!=iLast) {
				string = string.substring(0,iFirst) + string.substring(iFirst + lengthOf(unwantedDupes[i]));
				i=-1; /* check again */
			}
		}
		unwantedDbls = newArray("_-","-_","__","--","\\+\\+");
		for (i=0; i<lengthOf(unwantedDbls); i++){
			iFirst = indexOf(string,unwantedDbls[i]);
			if (iFirst>=0) {
				string = string.substring(0,iFirst) + string.substring(string,iFirst + lengthOf(unwantedDbls[i])/2);
				i=-1; /* check again */
			}
		}
		string = string.replace("_\\+", "\\+"); /* Clean up autofilenames */
		/* cleanup suffixes */
		unwantedSuffixes = newArray(" ","_","-","\\+"); /* things you don't wasn't to end a filename with */
		extStart = lastIndexOf(string,".");
		sL = lengthOf(string);
		if (sL-extStart<=4 && extStart>0) extIncl = true;
		else extIncl = false;
		if (extIncl){
			preString = substring(string,0,extStart);
			extString = substring(string,extStart);
		}
		else {
			preString = string;
			extString = "";
		}
		for (i=0; i<lengthOf(unwantedSuffixes); i++){
			sL = lengthOf(preString);
			if (endsWith(preString,unwantedSuffixes[i])) {
				preString = substring(preString,0,sL-lengthOf(unwantedSuffixes[i])); /* cleanup previous suffix */
				i=-1; /* check one more time */
			}
		}
		if (!endsWith(preString,"_lzw") && !endsWith(preString,"_lzw.")) preString = replace(preString, "_lzw", ""); /* Only want to keep this if it is at the end */
		string = preString + extString;
		/* End of suffix cleanup */
		return string;
	}