/* 
 *  Lachie's Custom Colony Counter
 *  Count colonies from images taken on lightbox with dSLR
 *  
 *  Code by Lachlan Whitehead (whitehead@wehi.edu.au)
 *  November 2013
 *  
 */


/* 
 *  Written to count colonies in images captured in round agar plates by an Olympus C-5060
 *  Single image or batch.
 *  Table will be given the name of the experiment specified in the pop-up menu.
 *  Output options - yes/no to generate mask images, then burn data (count, avg size, min/max size)
 * 		     onto the image
 *  Advanced options - Will open a new menu with inputs for rolling ball radius and min-size filter
 *  		       This needs some improvement for feedback purposes?
 *
 *  
 *  Needs a clean up and some better variable control to make more modular
 *  
 */


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////


//Set up variables (add any that are needed dir1,dir2,list, and fs are all required by functions);
var dir1="C:\\";
var dir2="C:\\";
var list = newArray();
var fs = File.separator();

CleanUp();

options=custom_menu();

Experiment_Title = options[0];Generate_Output = options[1];
BurnCaption = options[2];

//Setup custom results table
Table_Heading = Experiment_Title;

columns = newArray("Filename","Count", "avg", "StDev");
table = generateTable(Table_Heading,columns);
firstRun=true;


//Batch a directory?
batchFlag = Batch_Or_Not();

run("Set Measurements...", "  area limit redirect=None decimal=1");


for(i=0;i<list.length;i++){

	//If we're batching, and it's not a directory, open the next file (This was one if statement, but works better separately
	if(!File.isDirectory(dir1+list[i])){
		if(batchFlag){
			open(dir1+list[i]);
		}

		if(firstRun){
			defined_size = get_well_size(dir1);
		}
		fname = getInfo("image.filename");

		/////////////////SEGMENTATION/////////////////////////////////
		run("16-bit");
		run("Subtract Background...", "rolling="+options[6]+" light");
		setAutoThreshold("Otsu");
		setOption("BlackBackground", true);
		run("Convert to Mask");
		run("Watershed");
		roiManager("Show All");
		roiManager("Select",0);

		if(defined_size){
			if(!(firstRun)){
				CleanUp();
				roiManager("Open",dir1+"temp.roi.zip");
				waitForUser("Move circle to center of well");
				firstRun = false;

			}else{
				firstRun = false;
			}
		}else{
			showMessage("ROI not defined?");
		}

		run("Analyze Particles...", "size="+options[7]+"-50000 circularity=0.30-1.00 show=[Overlay Outlines] clear");
		count=nResults;

		/////////////////////////Finished segmentation //////////////////////////////////////////

		//Summarise results
		resultsArray=newArray();
		for(j=0;j<count;j++){
			resultsArray=Array.concat(resultsArray,getResult("Area",j));
		};
		Array.getStatistics(resultsArray,min,max,avg,stDev);

		////Generating Output mask image (if required)//////
		if(Generate_Output){
			run("Revert");
			run("Duplicate...", "title=overlay");
			roiManager("Show All");
			roiManager("Show None");
			run("Flatten");

			getDimensions(image_width,image_height,x,x,x);
			setForegroundColor(255, 255, 255); //Adjust Caption color
			setFont("SansSerif", 18, "bold"); //adjust to change appearance of caption ("bold" can be removed and "SansSerif" can be changed to "Serif");
			xpos=10;ypos=image_height-60; //adjust these to move the caption around

			if(BurnCaption){
				caption=build_caption(options,resultsArray);
				drawString(caption,xpos,ypos);
			}

			saveAs("Tif",dir2+fname+"_mask.tif");
			close("overlay");
		}

	//Putting the results in an array
	result_to_log = newArray(fname,count,avg,stDev);

	//Log the results into the table
	logResults(table,result_to_log);
	}

	if(batchFlag){
		run("Close All");
	}
}

delete=File.delete(dir1+"temp.roi.zip");
//CleanUp();

selectWindow(Experiment_Title);
if(batchFlag){
	if(File.exists(dir2+Experiment_Title+".txt")){
		overwrite=getBoolean("Warning\nResult table file alread exists, overwrite?");
			if(overwrite==1){
				saveAs("Text",dir2+Experiment_Title+".txt");
			}
	}else{
		saveAs("Text",dir2+Experiment_Title+".txt");
	}



////////////////////////////////////////////////////
// Functions 					  //
////////////////////////////////////////////////////

function get_well_size(roi_path){
	run("Hide Overlay");
	setTool("oval");
	waitForUser("Draw circle");
	run("ROI Manager...");
	roiManager("Add");
	roiManager("Save", roi_path+"temp.roi.zip");
	roiManager("Show None");
	return true;
}

function custom_menu(){

	instructions = "- Label the experiment.\n\r\n- Select whether or not to generate output images displaying\ncounts and other information.\n\r\n- Select \"Advanced Options\" if counts are not to your satisfaction\n\r\n";

	menu_title = "Lachie's custom colony counter";
	Dialog.create(menu_title);
	Dialog.setInsets(0, 20, 0);
  	Dialog.addMessage("Instructions:");
  	Dialog.addMessage(instructions);
  	Dialog.setInsets(0, 20, 0);
  	Dialog.addString("Experiment Title:", "colony count assay", 25);
  	Dialog.addCheckbox("Generate Output Masks", true);
  	Dialog.setInsets(0, 40, 0);
  	Dialog.addCheckbox("Burn label into output masks", true);
  	Dialog.setInsets(0, 80, 0);
  	Dialog.addCheckbox("Count", true);
  	Dialog.setInsets(0, 80, 0);
  	Dialog.addCheckbox("Average Size", true);
  	Dialog.setInsets(0, 80, 0);
  	Dialog.addCheckbox("Min / Max Size", false);
  	Dialog.addMessage("");
  	Dialog.addCheckbox("Advanced Options", false);

  	Dialog.show();
  	Exp_Title = Dialog.getString();
  	Generate_Output = Dialog.getCheckbox();
  	Burn_Caption = Dialog.getCheckbox();
  	AddCount = Dialog.getCheckbox();
  	AddAverage = Dialog.getCheckbox();
  	AddMinMax = Dialog.getCheckbox();
	AdvOpt = Dialog.getCheckbox();

	if(AdvOpt){
		Dialog.create("Advanced Options");
		Dialog.addMessage("Adjust as needed");
		Dialog.addNumber("Rolling ball radius for background subtraction", 50.0, 1, 4, "pixels")
		Dialog.addNumber("Minimum size of detectable colony", 25, 1, 4, "pixels")
		bg_sub = Dialog.getNumber();
		min_size = Dialog.getNumber();
		Dialog.show();
	}else{
		bg_sub=50;
		min_size=50;
	}
  	return newArray(Exp_Title,Generate_Output,Burn_Caption,AddCount,AddAverage,AddMinMax,bg_sub,min_size);
}

function build_caption(input_options,results_Array){
	Experiment_Title = input_options[0];Generate_Output = input_options[1];
	BurnCaption = input_options[2];AddCount = input_options[3];
	AddAverage = input_options[4];minmax = input_options[5];

	Array.getStatistics(results_Array,min,max,avg,stDev);
	count=results_Array.length;

	a="";b="";c="";d="";
	if(AddCount){b = "count = "+count +"\n";}
	if(AddAverage){c = "Avg size = " +avg+" pixels \n";}
	if(minmax){d = "min \\ max ="+min+" \\ "+max +" pixels\n";}

	asdf = b+c+d;

	return asdf;
}

//Generate a custom table
//Give it a title and an array of headings
//Returns the name required by the logResults function
function generateTable(tableName,column_headings){
	if(isOpen(tableName)){
		selectWindow(tableName);
		run("Close");
	}
	tableTitle=tableName;
	tableTitle2="["+tableTitle+"]";
	run("Table...","name="+tableTitle2+" width=600 height=250");
	newstring = "\\Headings:"+column_headings[0];
	for(i=1;i<column_headings.length;i++){
			newstring = newstring +" \t " + column_headings[i];
	}
	print(tableTitle2,newstring);
	return tableTitle2;
}


//Log the results into the custom table
//Takes the output table name from the generateTable funciton and an array of resuts
//No checking is done to make sure the right number of columns etc. Do that yourself
function logResults(tablename,results_array){
	resultString = results_array[0]; //First column
	//Build the rest of the columns
	for(i=1;i<results_array.length;i++){
		resultString = toString(resultString + " \t " + results_array[i]);
	}
	//Populate table
	print(tablename,resultString);
}

//Choose what to batch on
function Batch_Or_Not(){
	// If an image is open, run on that
	if(nImages == 1){
		fname = getInfo("image.filename");
		dir1 = getInfo("image.directory");
		dir2 = dir1 + "output" + fs;
		list=newArray("temp");
		list[0] = fname;
		batchFlag = false;
	// If more than one is, choose one
	}else if(nImages > 1){
		waitForUser("Select which image you want to run on");
		fname = getInfo("image.filename");
		dir1 = getInfo("image.directory");
		dir2 = dir1 + "output" + fs;
		list=newArray("temp");
		list[0] = fname;
		batchFlag = false;
	// If nothing is open, batch a directory
	}else{
		dir1 = getDirectory("Select source directory");
		list= getFileList(dir1);
		dir2 = dir1 + "output" + fs;
		batchFlag = true;
	}

	if(!File.exists(dir2)){
		File.makeDirectory(dir2);
	}
	return(batchFlag);
}

function CleanUp(){
	if(isOpen("ROI Manager")){
		selectWindow("ROI Manager");
		run("Close");
	}
	if(isOpen("Log")){
		selectWindow("Log");
		run("Close");
	}
}
