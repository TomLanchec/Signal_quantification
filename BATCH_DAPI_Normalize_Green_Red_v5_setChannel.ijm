// ===== BATCH Fiji Macro v5: Measure per channel by switching channels (no redirect/duplicates) =====
// - Processes all images in a chosen folder
// - Segmentation from DAPI mask; measurements on the source hyperstack via Stack.setChannel()
// - Saves CSVs to a fixed folder in your home (edit SAVE_DIR if needed)

// -------- Fixed save directory --------
SAVE_DIR = getDirectory("home") + "Downloads/Fiji_Results/";
if (!File.exists(SAVE_DIR)) File.makeDirectory(SAVE_DIR);

// -------- Parameters once for the batch --------
Dialog.create("Batch per-nucleus quant (Green/Red normalized by DAPI) - v5 setChannel");
Dialog.addNumber("DAPI channel index (1..N)", 3);
Dialog.addNumber("Green channel index (1..N)", 2);
Dialog.addNumber("Red channel index (1..N)", 1);
Dialog.addCheckbox("If Z>1: Max-intensity project (per channel)", false);
Dialog.addCheckbox("Subtract background (rolling ball) on source image", true);
Dialog.addNumber("Rolling ball radius (pixels)", 50);
Dialog.addCheckbox("Median filter on source image", true);
Dialog.addNumber("Median radius (pixels)", 1.0);
Dialog.addString("Auto-threshold for DAPI (Otsu/Triangle/Li/...)", "Otsu");
Dialog.addNumber("Min nucleus area (current units)", 50);
Dialog.addNumber("Max nucleus area", 1e12);
Dialog.addCheckbox("Watershed", false);
Dialog.show();

dapiIdx  = Dialog.getNumber();
gIdx     = Dialog.getNumber();
rIdx     = Dialog.getNumber();
doZProj  = Dialog.getCheckbox();
doBG     = Dialog.getCheckbox();
rbRad    = Dialog.getNumber();
doMed    = Dialog.getCheckbox();
medRad   = Dialog.getNumber();
thrMeth  = Dialog.getString();
minA     = Dialog.getNumber();
maxA     = Dialog.getNumber();
doWat    = Dialog.getCheckbox();

// -------- Choose input folder --------
inDir = getDirectory("Choose a folder of images");
if (inDir=="") exit("No folder chosen.");
exts = newArray(".tif",".tiff",".czi",".nd2",".lif",".lsm",".oib",".oif",".ics",".png",".jpg",".jpeg");
files = getFileList(inDir);
if (files.length==0) exit("No files in folder.");

for (i=0; i<files.length; i++) {
    name = files[i]; path = inDir + name;
    if (File.isDirectory(path)) continue;
    lower = toLowerCase(name); ok=false;
    for (e=0; e<exts.length; e++) if (endsWith(lower, exts[e])) ok=true;
    if (!ok) continue;

    open(path);
    srcTitle = getTitle();
    Stack.getDimensions(w,h,C,Z,T);
    if (dapiIdx<1 || dapiIdx>C || gIdx<1 || gIdx>C || rIdx<1 || rIdx>C) {
        print("\\>> Skip (C mismatch): " + name); if (isOpen(srcTitle)) { selectWindow(srcTitle); close(); } continue;
    }

    // Optional Z projection (keeps channels)
    if (Z>1 && doZProj) {
        selectWindow(srcTitle);
        run("Z Project...", "projection=[Max Intensity]");
        close(srcTitle);
        rename(srcTitle);
        Stack.getDimensions(w,h,C,Z,T);
    }

    // Optional preprocessing on the source image
    selectWindow(srcTitle);
    if (doBG) run("Subtract Background...", "rolling="+rbRad+" stack");
    if (doMed) run("Median...", "radius="+medRad+" stack");

    // DAPI mask from the same image
    run("Duplicate...", "title=[DAPI_mask] duplicate channels="+dapiIdx);
    selectWindow("DAPI_mask");
    run("Auto Threshold", "method="+thrMeth);
    setOption("BlackBackground", true);
    run("Convert to Mask");
    if (doWat) run("Watershed");
    run("Set Measurements...", "area mean integrated redirect=None decimal=6");
    roiManager("Reset");
    run("Analyze Particles...", "size="+minA+"-"+maxA+" show=Nothing add clear include");
    nROIs = roiManager("count");
    if (nROIs==0) { run("Invert"); if (doWat) run("Watershed"); roiManager("Reset"); run("Analyze Particles...", "size="+minA+"-"+maxA+" show=Nothing add clear include"); nROIs = roiManager("count"); }
    if (nROIs==0) { print("\\>> No nuclei: " + name); close("DAPI_mask"); if (isOpen(srcTitle)) { selectWindow(srcTitle); close(); } roiManager("Reset"); continue; }
    close("DAPI_mask");

    // Measurements on the source hyperstack
    selectWindow(srcTitle);
    run("Set Measurements...", "area mean integrated decimal=6");

    // DAPI
    Stack.setChannel(dapiIdx);
    run("Clear Results"); roiManager("Measure");
    nD = nResults; A  = newArray(nD); MD = newArray(nD); ID = newArray(nD);
    for (r=0; r<nD; r++) { A[r]=getResult("Area", r); MD[r]=getResult("Mean", r); ID[r]=getResult("IntDen", r); }

    // GREEN
    Stack.setChannel(gIdx);
    run("Clear Results"); roiManager("Measure");
    nG = nResults; MG = newArray(nG); IG = newArray(nG);
    for (r=0; r<nG; r++) { MG[r]=getResult("Mean", r); IG[r]=getResult("IntDen", r); }

    // RED
    Stack.setChannel(rIdx);
    run("Clear Results"); roiManager("Measure");
    nR = nResults; MR = newArray(nR); IR = newArray(nR);
    for (r=0; r<nR; r++) { MR[r]=getResult("Mean", r); IR[r]=getResult("IntDen", r); }

    // Assemble tidy table
    n = minOf(nD, nG); n = minOf(n, nR);
    run("Clear Results");
    for (r=0; r<n; r++) {
      setResult("Area", r, A[r]);
      setResult("Mean_DAPI", r, MD[r]);
      setResult("IntDen_DAPI", r, ID[r]);
      setResult("Mean_Green", r, MG[r]);
      setResult("IntDen_Green", r, IG[r]);
      setResult("Mean_Red", r, MR[r]);
      setResult("IntDen_Red", r, IR[r]);
      md = MD[r]; idd = ID[r]; if (md==0) md=NaN; if (idd==0) idd=NaN;
      setResult("Norm_Mean_Green/Mean_DAPI", r, MG[r]/md);
      setResult("Norm_Mean_Red/Mean_DAPI",  r, MR[r]/md);
      setResult("Norm_IntDen_Green/IntDen_DAPI", r, IG[r]/idd);
      setResult("Norm_IntDen_Red/IntDen_DAPI",  r, IR[r]/idd);
      setResult("Image", r, srcTitle);
      setResult("ROI_Index", r, r+1);
    }
    updateResults();

    // Save CSV
    saveName = replace(srcTitle, " ", "_"); saveName = replace(saveName, "/", "_"); saveName = replace(saveName, "\\", "_");
    savePath = SAVE_DIR + saveName + "_DAPI_norm_results.csv";
    saveAs("Results", savePath);
    print("\\>> Saved CSV to: " + savePath);

    // Cleanup
    if (isOpen(srcTitle)) { selectWindow(srcTitle); close(); }
    roiManager("Reset");
}
print("\\>> Batch finished.");
