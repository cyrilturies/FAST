//	FAST (Fluorescence image AnalysiS Tool) - Cyril TURIÈS - Comments or improvements are welcome (mailto: cyril.turies@ineris.fr)
// Image processing pipeline:
// 	- List all files containing user-defined extension (.czi .zvi .nd2 or .tif) within selected directory and sub-directories
// 	- Apply the user-defined threshold (default 290) then analyse particles above the threshold
// 	- Group all pixels above the threshold in one Region Of Interest and save this ROI in a zip file within work directory
// 	- Open images one by one to check the auto-selected area
// 	- User can confirm the ROI, modify it directly or remove image from further analysis
// 	- result table is automatically copied to clipboard at the end of the macro
// Recent updates:
//	- 10/2014 added help message accessible from dialogBox to explain tickboxes
//	- 10/2014 added silent mode for new measurement of existing data without prompt
//	- 10/2014 CSV saving option in work directory
//	- 10/2014 added upper/lower case image selection
// 	- 01/2015 fixed bug reseting result table
//	- 01/2015 add new Zeiss ZEN .czi file format and Dialog.setLocation()
//	- 06/2016 Restart Mode to restart analysis after interruption of auto processing
//  - 02/2018 added Nikon .nd2 file type
//  - 07/2018 Former name "Cyp19a1b-GFP Analysis" changed to FAST (Fluorescence image AnalysiS Tool)

v = "v2.4";
date = "07/2018";

requires("1.49o"); // 1.49o23

// DialogBox Help message
  help = "<html>"
	+"<h2><u>FAST (Fluorescence image AnalysiS Tool) help</u></h2>"
	+"<b>Threshold</b> : set lower threshold value for pixel intensity, segmenting the image<br>into features of interest (above threshold) and background.<br><br>"
	+"<b>File type</b> : select image type or extension between CZI (ZEN Zeiss format)<br>"
	+"ZVI (Zeiss Vision Image), ND2 Nikon file and TIFF (Tagged Image File Format).<br><br>"
	+"<b>Create ROIs</b> : Step 1, Analyse pixels above the user-defined threshold value<br>"
	+"and automatically saves Regions Of Interest zip file in the image directory.<br><br>"
	+"<b>Measure ROIs</b> : Step 2 of image analysis, user checks each image individually<br>and measure previously created ROIs.<br><br>"
	+"<b>Overwrite existing ROIs</b> : if selected, the macro will overwrite ROIs zip files<br>without prompting the user many times.<br><br>"
	+"<b>Silent Mode</b> : if selected, the macro will measure all images with their<br>associated ROI without prompting for individual ROI check.<br><br>"
	+"<b>Restart Mode</b> : when auto processing is cancelled accidentally,<br>this mode checks the last ROI created and restarts analysis from this point.<br><br>"
	+"*ROI = Region Of Interest<br><br>"
	+"<i>-> Any comment/improvement is welcome</i> <font color=\"blue\"><u>cyril.turies@ineris.fr</u></font<br>"
	+v+" - "+date
	+"</html>";
	
// DialogBox to set options
	Dialog.create("FAST "+v+" options");
	Dialog.addChoice("File type", newArray(".czi",".zvi",".tif",".nd2"), ".czi");
	Dialog.addNumber("Threshold value:", 290);
	Dialog.setInsets(0, 0, 0);
	Dialog.addMessage("Images auto processing:");
	Dialog.setInsets(0, 20, 0);
	Dialog.addCheckbox("Create Regions Of Interest (Step 1)", true);
	Dialog.addCheckbox("Measure ROIs (Step 2)", true);
	Dialog.setInsets(0, 0, 0);
	Dialog.addMessage("Specific parameters: (see Help)");
	Dialog.addCheckbox("Overwrite existing ROIs", false);
	Dialog.addCheckbox("Silent Mode", false);
	Dialog.addCheckbox("Restart Mode", false);
	Dialog.addHelp(help);
	Dialog.show();

	ext = Dialog.getChoice();
	thr = Dialog.getNumber();
	def = Dialog.getCheckbox();
	mes = Dialog.getCheckbox();
	overwrt = Dialog.getCheckbox();
	silent = Dialog.getCheckbox();
	resume = Dialog.getCheckbox();

	dir = getDirectory("Choose a Directory ");
	svdir = dir;
	k = 1;
	
// Reset ROI Manager
	c = roiManager("count");
	if (c != 0) {
		showMessageWithCancel("Warning!","Content of ROI manager will be erased\nContinue?");
		roiManager("reset");
	}

// test for upper-case extension
	upext = toUpperCase(ext);
	
// Auto threshold, select ROI and auto save
setBatchMode(true);
	
	if (def == true) listFiles(dir);
	
setBatchMode(false);

// Goto image 1 to check each ROI
	k = 1;
	run("Set Measurements...", "area mean standard min integrated limit display redirect=None decimal=0");

// Reset result table
	if (nResults != 0) {
//		showMessageWithCancel("Warning!","Content of Result Table will be erased");
		run("Clear Results");
	}

// Individual check of ROI
	if (mes == true) {
		// Activate batchmode to stop blinking of images
		if (silent == 1){
			setBatchMode(true);
			checkFiles(dir);
			setBatchMode(false);
		} else {
			checkFiles(dir);
		}
		updateResults();
		svchoice = getBoolean("Do you want to save the Result table\nto work directory?");
		selectWindow("Results");
			if (svchoice == 1) {
				if (File.exists(svdir+"Results.csv")) {
					choice = getBoolean("A file named Results.csv already exists.\nOverwrite?");
					if (choice == 1) saveAs("Results", svdir+"Results.csv");
					if (choice == 0) {
						newdir = getDirectory("Save to");
						saveAs("Results", newdir+"Results.csv");
					}
				} else saveAs("Results", svdir+"Results.csv");
			}

	}

///////////////////////////////////
	
// Fonction "listfile" to select pixel area above user-defined threshold and auto save of ROI into [imagename].zip file

	function listFiles(dir) {
		list = getFileList(dir);
	for (i=0; i<list.length; i++) {
		if (endsWith(list[i], "/")) {
			listFiles(""+dir+list[i]);
		}
		else {
			if (endsWith(list[i], ext) || endsWith(list[i], upext)) {
				path = dir + list[i];
				if (lastIndexOf(list[i], ext) == -1){
					prefix = substring(list[i], 0, lastIndexOf(list[i], upext));
				} else {
					prefix = substring(list[i], 0, lastIndexOf(list[i], ext));
					}
				// Restart Mode selection of images without ROI.zip
				if (resume == 1 && File.exists(dir + prefix + ".zip")) {
					print((k++) + ": " + path);
				}
				else {
					print((k++) + ": " + path);
					// open image file, set threshold and analyse particles
					if (ext == ".zvi" || ext == ".czi") {
						run("Bio-Formats Importer", "open=["+ path +"]" + " autoscale color_mode=Default view=[Standard ImageJ] stack_order=Default");
					} else {
						open(path);
					}
					resetThreshold;
					getMinAndMax(min, max);
					setThreshold(thr, max, "over/under");
					run("Select All");
					run("Analyze Particles...", "size=2-Infinity exclude include add");
					n = roiManager("count");
					// sum particles in a unique ROI
					if (n>1) {
						roiManager("deselect");
						roiManager("XOR");
						roiManager("add");
						for (j=1; j<n+1; j++) {
							roiManager("select", 0);
							roiManager("delete");
							}
						}
					// save ROI.zip
					n = roiManager("count");
					if (n>0) {
						
						// check of existing ROI.zip
						if (File.exists(dir+prefix+".zip")) {
							if (overwrt == 1) {
								roiManager("Save", dir+prefix+".zip");
							} else {
							choice = getBoolean("A file named "+prefix+".zip already exists.\nOverwrite?");
							if (choice == 1) roiManager("Save", dir+prefix+".zip");
							}
						} else {
							roiManager("Save", dir+prefix+".zip");
						}
						roiManager("reset");
						}
					close();
				}
				}
			}
		}
	}

// Fonction "checkfiles" to individually check pixel area above user-defined threshold

	function checkFiles(dir) {
		list = getFileList(dir);
	for (i=0; i<list.length; i++) {
		if (endsWith(list[i], "/")) {
			checkFiles(""+dir+list[i]);
		} else {
			if (endsWith(list[i], ext) || endsWith(list[i], upext)) {
				if (lastIndexOf(list[i], ext) == -1){
					prefix = substring(list[i], 0, lastIndexOf(list[i], upext));
				} else {
				prefix = substring(list[i], 0, lastIndexOf(list[i], ext));
				}
				path = dir + list[i];
				// open image file and associated ROI.zip
				if (ext == ".zvi" || ext == ".czi") {
					run("Bio-Formats Importer", "open=["+ path +"]" + " autoscale color_mode=Default view=[Standard ImageJ] stack_order=Default");
				} else {
					open(path);
				}
				getLocationAndSize(x, y, width, height);
				if (File.exists(dir+prefix+".zip")) {
					open(dir+prefix+".zip");
					roiManager("select", 0);
					// Silent mode if ROI is found
					if (silent == 1){
						resetThreshold;
						getMinAndMax(min, max);
						setThreshold(thr, max, "over/under");
						roiManager("Measure");
						roiManager("reset");
						setResult("Label", nResults-1, list[i]);
						updateResults();
						close();
					} else {
						// Normal processing mode ROI check DialogBox
						Dialog.create("ROI check");
						Dialog.addMessage("=> "+prefix);
						items = newArray("Yes", "No");
						Dialog.addRadioButtonGroup("Exclude image from analysis:", items, 1, 2, "No");
						Dialog.addRadioButtonGroup("Redefine area manually:", items, 1, 2, "No");
						Dialog.setLocation(x+width,y);
						Dialog.show;
						skip = Dialog.getRadioButton;
						area = Dialog.getRadioButton;
						
						if (skip == "Yes") {
							close();
							roiManager("reset");
						} else {
							if (area == "Yes") {
								roiManager("reset");
								resetThreshold;
								getMinAndMax(min, max);
								setThreshold(thr, max, "over/under");
								run("Analyze Particles...", "size=2-Infinity exclude include add");
								setTool("freehand");
								waitForUser("ROI edition","Edit area before you click on OK\n\nPress and hold key:\n   ALT = Substract selected area \n   SHIFT = Add selected area");
								if (selectionType() == -1) waitForUser("WARNING","Without selection this image will be excluded from analysis\n \n=> Select area then click on -OK-");
								if (selectionType() != -1) {
									roiManager("add");
									roiManager("Save", dir+prefix+".zip");
									roiManager("deselect");
									roiManager("Measure");
									roiManager("reset");
									setResult("Label", nResults-1, list[i]);
								}
							}
							if (area == "No") {
								resetThreshold;
								getMinAndMax(min, max);
								setThreshold(thr, max, "over/under");
								roiManager("deselect");
								roiManager("Measure");
								roiManager("reset");
								setResult("Label", nResults-1, list[i]);
								}
							updateResults();
							close();
							}
					}
				} else {
					// Silent mode if no ROI is found
					if  (silent == 1){
						print("No ROI.zip for: "+dir+prefix);
						close();
					// Normal mode if no pixel found in ROI
					} else {
						choice = getBoolean("No pixel area >> threshold found on the image.\n \nExclude image from analysis?\n|  Yes  | = Validate\n|  No  | = Redefine area");
							if (choice == 0) {
								roiManager("reset");
								resetThreshold;
								run("Select None");
								getMinAndMax(min, max);
								setThreshold(thr, max, "over/under");
								setTool("freehand");
								waitForUser("Area selection","Select new area\nbefore you click on OK");
								if (selectionType() == -1) waitForUser("WARNING","Without selection this image will be excluded from analysis\n \n=> Select area then click on -OK-");
								if (selectionType() != -1) {
									roiManager("add");
									roiManager("Save", dir+prefix+".zip");
									roiManager("deselect");
									roiManager("Measure");
									roiManager("reset");
									setResult("Label", nResults-1, list[i]);
									updateResults();
								}
								close();
							}
							if (choice == 1) {
							close();
							}
						}
					}
				}
			}
		}
	}
