# SketchUp to OpenFOAM
# Converts a Sketchup file into an OpenFOAM case
# Usage: Copy the plugin and place it in the Plugins folder
# Usage: Create your geometry in SketchUp. Note that the geometry must be in GROUP (number of groups is immaterial)
# Usage: Choose "Export to OpenFOAM" under Tools menu
# Output: OpenFOAM files created in a folder called "case" in the working directory (displayed on screen)
# Output: Each GROUP is written out as a STL file (constant/triSurface)
# Output: Name of the STL file and solid being the name of the GROUP
# Output: 3 folders in "case" directory - 0, constant and system
# Output: "0" folder has all the variables - p, p_rgh, k, epsilon, omega, T and U
# Output: "constant" folder contains 2 subfolders - polyMesh and triSurface
# Output: "polyMesh" contains blockMeshDict with a base grid of 10 x 10 x 10
# Output: "triSurface" contains the STL files of the GROUPs
# Output: "system" folder contains the files - controlDict, decomposeParDict, fvSchemes, fvSolutions, snappyHexMeshDict
# Limitations: Need to manually delete the "case" folder before exporting every time
# Notes: No warranty on results. Use at your own risk/discretion
# Notes: Code is free. Appreciate feedback/acknowledging when using it
# Created by: Venugopalan Raghavan
# STL Plugin amended from the skp_to_dxf.rb plugin (by Nathan Bromham & Konrad Shroeder)

# Major Update 20 Jun 2015: "block" in blockMeshDict corrected to "blocks"
# Major Update 20 Jun 2015: Removed spacing in div(var1, var2) that was causing problems. Should be only div(var1,var2)
# Major Update 21 Jun 2015: Redefined order of points in blockMeshDict. Original order does not allow snappyHexMesh to work

require 'sketchup.rb'

def startup
	Dir.mkdir($cwd+"/case")
	Dir.mkdir($cwd+"/case/0")
	Dir.mkdir($cwd+"/case/constant")
	Dir.mkdir($cwd+"/case/system")
	Dir.mkdir($cwd+"/case/constant/polyMesh")
	Dir.mkdir($cwd+"/case/constant/triSurface")
	nn = File.new($cwd+"/case/paraview.foam","w")
end

def stl_export
	$stl_conv = 0.0254
    entities = $model.entities
            
	for p in 0..entities.length-1 do
		entity = entities[p]
		model_name = entity.name
		if model_name.include? "_Ref"
			model_name = model_name.split("_").first
		end
		out_name = $cwd + "/case/constant/triSurface/" + model_name + ".stl"
		$mesh_file = File.new( out_name , "w" )  
		$mesh_file.puts("solid " + model_name)
		tform = entity.transformation
		e = entity.entities
		for i in 0..e.length-1 do
			ety = e[i]
			if ety.typename == "Face"
				mesh = ety.mesh 7
				mesh.transform! tform
				polygons = mesh.polygons
				polygons.each do |polygon|
					if (polygon.length == 3)
						nx = mesh.normal_at(polygon[0].abs).x.to_s
						ny = mesh.normal_at(polygon[0].abs).y.to_s
						nz = mesh.normal_at(polygon[0].abs).z.to_s
						$mesh_file.puts("facet normal #{nx} #{ny} #{nz}")
						$mesh_file.puts("outer loop")
						for j in 0..2 do
							x = (mesh.point_at(polygon[j].abs).x.to_f * $stl_conv).to_s
							y = (mesh.point_at(polygon[j].abs).y.to_f * $stl_conv).to_s
							z = (mesh.point_at(polygon[j].abs).z.to_f * $stl_conv).to_s
							$mesh_file.puts("vertex #{x} #{y} #{z}")
						end #end for
						$mesh_file.puts("endloop\nendfacet")
					end #end if
				end	#end loop
			end # end if
		end # end for
		$mesh_file.puts("endsolid " + model_name)
		$mesh_file.close
	end # end for
end # end function
	
def header
	$var_file.puts("/*------------------------------------------------------------------------*\\\n")
	$var_file.puts("|=========                 |                                               |\n")
	$var_file.puts("|\\\\      /   F ield        | OpenFOAM: The Open Source CFD Toolbox         |\n")
	$var_file.puts("| \\\\    /    O peration    | Version:  2.1.0                               |\n")
	$var_file.puts("|  \\\\  /     A nd          | Web:      www.OpenFOAM.org                    |\n")
	$var_file.puts("|   \\\\/      M anipulation |                                               |\n")
	$var_file.puts("\*------------------------------------------------------------------------*/\n")
	$var_file.puts("FoamFile\n")
	$var_file.puts("{")
	$var_file.puts("\t/* EOFv for SketchUp Exporter!*/\n")
	$var_file.puts("\tversion\t2.1;\n")
	$var_file.puts("\tformat\tascii;\n")
end

def skp_of_export
    $model = Sketchup.active_model
	$bounds = $model.bounds
    model_filename = File.basename($model.path)
	entities = $model.entities
    if( model_filename == "" )
		model_filename = "model"
    end
	$cwd = Dir.pwd
	startup
    group_count = 0
	if (Sketchup.version_number==7)
		$model.start_operation("export_OF",true)
    else
		$model.start_operation("export_OF")
    end
   	
	UI.messagebox("Number of groups = #{entities.length}",MB_OK)
	UI.messagebox("Files will be written to: #{$cwd}/case",MB_OK)
		
	for p in 0..entities.length-1 do
		entity = entities[p]
		if entity.typename == "Group"
			if entity.name == ""
				entity.name="GROUP"+group_count.to_s
				group_count+=1
			end
		end
	end
	
	variables = ["U","p","p_rgh","k","epsilon","omega","T"]
	faces = ["Left","Right","Front","Back","Top","Bottom"]
	
	for var in variables
		$var_file = File.new($cwd + "/case/0/" + var, "w")
		header
		case var
		when "U"
			$var_file.puts("\tclass\tvolVectorField;")
		else
			$var_file.puts("\tclass\tvolScalarField;")
		end
		$var_file.puts("\tobject\t"+var+";")
		$var_file.puts("}")
		case var
		when "p","p_rgh" then
			$var_file.puts("\ndimensions\t[0 2 -2 0 0 0 0];")
			$var_file.puts("\ninternalField\tuniform\t0;")
		when "k" then
			$var_file.puts("\ndimensions\t[0 2 -2 0 0 0 0];")
			$var_file.puts("\ninternalField\tuniform\t0.1;")
		when "epsilon" then
			$var_file.puts("\ndimensions\t[0 2 -3 0 0 0 0];")
			$var_file.puts("\ninternalField\tuniform\t0.1;")
		when "omega" then
			$var_file.puts("\ndimensions\t[0 0 -1 0 0 0 0];")
			$var_file.puts("\ninternalField\tuniform\t0.1;")
		when "T" then
			$var_file.puts("\ndimensions\t[0 0 0 1 0 0 0];")
			$var_file.puts("\ninternalField\tuniform\t298.15;")
		when "U" then
			$var_file.puts("\ndimensions\t[0 1 -1 0 0 0 0];")
			$var_file.puts("\ninternalField\tuniform\t(0 0 0);")
		end
		$var_file.puts("\nboundaryField\n{\n")
		
		for f in faces 
			$var_file.puts("\t"+f)
			$var_file.puts("\t{")
			case var
			when "p","p_rgh"
				if f.include? "Back"
					$var_file.puts("\t\ttype\tfixedValue;\n\t")
					$var_file.puts("\t\tvalue\tuniform 0;\n\t}")
				else
					$var_file.puts("\t\ttype\tzeroGradient;\n\t}")
				end
			when "U"
				case f
				when "Front","Left","Right","Top"
					$var_file.puts("\t\ttype\tfixedValue;\n\t")
					$var_file.puts("\t\tvalue\tuniform (0 -2 0);\n\t}")
				when "Back"
					$var_file.puts("\t\ttype\tzeroGradient;\n\t}")
				when "Bottom"
					$var_file.puts("\t\ttype\tfixedValue;\n\t")
					$var_file.puts("\t\tvalue\tuniform (0 0 0);\n\t}")
				end
			when "k"
				case f
				when "Front","Left","Right","Top"
					$var_file.puts("\t\ttype\tfixedValue;\n\t")
					$var_file.puts("\t\tvalue\tuniform 0.1;\n\t}")
				when "Back"
					$var_file.puts("\t\ttype\tzeroGradient;\n\t}")
				when "Bottom"
					$var_file.puts("\t\ttype\tkqRWallFunction;\n\t")
					$var_file.puts("\t\tvalue\tuniform 0.1;\n\t}")
				end
			when "epsilon"
				case f
				when "Front","Left","Right","Top"
					$var_file.puts("\t\ttype\tfixedValue;\n\t")
					$var_file.puts("\t\tvalue\tuniform 0.1;\n\t}")
				when "Back"
					$var_file.puts("\t\ttype\tzeroGradient;\n\t}")
				when "Bottom"
					$var_file.puts("\t\ttype\tepsilonWallFunction;\n\t")
					$var_file.puts("\t\tvalue\tuniform 0.1;\n\t}")
				end
			when "omega"
				case f
				when "Front","Left","Right","Top"
					$var_file.puts("\t\ttype\tfixedValue;\n\t")
					$var_file.puts("\t\tvalue\tuniform 0.1;\n\t}")
				when "Back"
					$var_file.puts("\t\ttype\tzeroGradient;\n\t}")
				when "Bottom"
					$var_file.puts("\t\ttype\tomegaWallFunction;\n\t")
					$var_file.puts("\t\tvalue\tuniform 0.1;\n\t}")
				end
			when "T"
				$var_file.puts("\t\ttype\tzeroGradient;\n\t}")
			end
		end
		
		for p in 0..entities.length-1 do
			entity = entities[p]
			model_name = entity.name
			if model_name.include? "_Ref"
				model_name = model_name.split("_").first
			end
			mm = model_name
			$var_file.puts("\t"+mm+"_"+mm)
			$var_file.puts("\t{")
			case var
			when "p","p_rgh","T"
				$var_file.puts("\t\ttype\tzeroGradient;\n\t}")
			when "U"
				$var_file.puts("\t\ttype\tfixedValue;")
				$var_file.puts("\t\tvalue\tuniform (0 0 0);\n\t}")
			when "k"
				$var_file.puts("\t\ttype\tkqRWallFunction;")
				$var_file.puts("\t\tvalue\tuniform 0.1;\n\t}")
			when "omega"
				$var_file.puts("\t\ttype\tomegaWallFunction;")
				$var_file.puts("\t\tvalue\tuniform 0.1;\n\t}")
			when "epsilon"
				$var_file.puts("\t\ttype\tepsilonWallFunction;")
				$var_file.puts("\t\tvalue\tuniform 0.1;\n\t}")
			end
		end
		$var_file.puts("}")
		$var_file.close
	end
	constant_create
	controlDict_create
	decomposePar_create
	fvSchemes_create
	fvSolution_create
	snappymesh_create
	stl_export
	$model.commit_operation
end # end function

def constant_create
	$var_file = File.new($cwd + "/case/constant/polyMesh/blockMeshDict", "w")
	header
	$var_file.puts("\tclass\tdictionary;\n")
	$var_file.puts("\tlocation\tconstant;\n")
	$var_file.puts("\tobject\tblockMeshDict;\n}")
	$var_file.puts("\nconvertToMeters\t1;\n")
	$var_file.puts("\n\n")
	$var_file.puts("vertices")
	$var_file.puts("(")
	
	list = [2,3,1,0,6,7,5,4]
	
	minX = $bounds.corner(0)[0].to_f*0.0254
	minY = $bounds.corner(0)[1].to_f*0.0254
	minZ = $bounds.corner(0)[2].to_f*0.0254
	
	maxX = $bounds.corner(0)[0].to_f*0.0254
	maxY = $bounds.corner(0)[1].to_f*0.0254
	maxZ = $bounds.corner(0)[2].to_f*0.0254
	
	for l in 0..7
		x = $bounds.corner(l)[0].to_f*0.0254
		y = $bounds.corner(l)[1].to_f*0.0254
		z = $bounds.corner(l)[2].to_f*0.0254
		
		minX = (minX < x) ? minX : x
		minY = (minY < y) ? minY : y
		minZ = (minZ < z) ? minZ : z
		
		maxX = (maxX > x) ? maxX : x
		maxY = (maxY > y) ? maxY : y
		maxZ = (maxZ > z) ? maxZ : z
	end
	
	minX = minX - 100
	maxX = maxX + 100
	
	minY = minY - 100
	maxY = maxY + 100
	
	maxZ = 3*maxZ
	
	$var_file.puts("\t("+minX.to_s+" "+maxY.to_s+" "+maxZ.to_s+")")
	$var_file.puts("\t("+maxX.to_s+" "+maxY.to_s+" "+maxZ.to_s+")")
	$var_file.puts("\t("+maxX.to_s+" "+minY.to_s+" "+maxZ.to_s+")")
	$var_file.puts("\t("+minX.to_s+" "+minY.to_s+" "+maxZ.to_s+")")
	
	$var_file.puts("\t("+minX.to_s+" "+maxY.to_s+" "+minZ.to_s+")")
	$var_file.puts("\t("+maxX.to_s+" "+maxY.to_s+" "+minZ.to_s+")")
	$var_file.puts("\t("+maxX.to_s+" "+minY.to_s+" "+minZ.to_s+")")
	$var_file.puts("\t("+minX.to_s+" "+minY.to_s+" "+minZ.to_s+")")
	
	$var_file.puts(");")
	$var_file.puts("blocks\n(")
	$var_file.puts("\thex\t(0 1 2 3 4 5 6 7)\t(10 10 10)\tsimpleGrading\t(1 1 1)")
	$var_file.puts(");")
	
	$var_file.puts("edges\n(\n);")
	$var_file.puts("boundary\n(")
	
	$var_file.puts("\tLeft\n\t{")
	$var_file.puts("\t\ttype\tpatch;")
	$var_file.puts("\t\tfaces\n\t\t(")
	$var_file.puts("\t\t\t(0 4 7 3)\n\t\t);\n\t}")
	
	$var_file.puts("\tRight\n\t{")
	$var_file.puts("\t\ttype\tpatch;")
	$var_file.puts("\t\tfaces\n\t\t(")
	$var_file.puts("\t\t\t(1 2 6 5)\n\t\t);\n\t}")
	
	$var_file.puts("\tTop\n\t{")
	$var_file.puts("\t\ttype\tpatch;")
	$var_file.puts("\t\tfaces\n\t\t(")
	$var_file.puts("\t\t\t(0 3 2 1)\n\t\t);\n\t}")
	
	$var_file.puts("\tBottom\n\t{")
	$var_file.puts("\t\ttype\twall;")
	$var_file.puts("\t\tfaces\n\t\t(")
	$var_file.puts("\t\t\t(4 5 6 7)\n\t\t);\n\t}")
	
	$var_file.puts("\tFront\n\t{")
	$var_file.puts("\t\ttype\tpatch;")
	$var_file.puts("\t\tfaces\n\t\t(")
	$var_file.puts("\t\t\t(0 1 5 4)\n\t\t);\n\t}")
	
	$var_file.puts("\tBack\n\t{")
	$var_file.puts("\t\ttype\tpatch;")
	$var_file.puts("\t\tfaces\n\t\t(")
	$var_file.puts("\t\t\t(3 7 6 2)\n\t\t);\n\t}")
	
	$var_file.puts(");")
	$var_file.puts("mergePatchPairs\n(\n);")
	
	$var_file.close
	
	$var_file = File.new($cwd + "/case/constant/RASProperties", "w")
	header
	$var_file.puts("\tclass\tdictionary;\n")
	$var_file.puts("\tlocation\tconstant;\n")
	$var_file.puts("\tobject\tRASProperties;\n}")
	$var_file.puts("\nRASModel\tkEpsilon;")
	$var_file.puts("\nturbulence\ton;")
	$var_file.puts("\nprintCoeffs\ton;")
	$var_file.close
	
	$var_file = File.new($cwd + "/case/constant/transportProperties", "w")
	header
	$var_file.puts("\tclass\tdictionary;\n")
	$var_file.puts("\tlocation\tconstant;\n")
	$var_file.puts("\tobject\ttransportProperties;\n}")
	$var_file.puts("\ntransportModel\tNewtonian;")
	$var_file.puts("\nnu\tnu\t[0 2 -1 0 0 0 0]\t1.5E-05;")
	$var_file.close
	
end # end function

def snappymesh_create
    entities = $model.entities
	stlname = Array.new()
	refname = Array.new()
	localBounds = Array.new()
	for p in 0..entities.length-1 do
		entity = entities[p]
		yes1 = entity.typename == "Group"
		yes2 = entity.name.include? "_Ref"
		if ((yes1 == true) and (yes2 == true))
			stlname << entity.name.split("_").first
			refname << entity.name
			localBounds << entity.local_bounds
		elsif ((yes1 == true) and (yes2 == false)) 
			stlname << entity.name
		end
	end
	
	$var_file = File.new($cwd + "/case/system/snappyHexMeshDict", "w")
	header
	$var_file.puts("\tclass\tdictionary;\n")
	$var_file.puts("\tlocation\tsystem;\n")
	$var_file.puts("\tobject\tsnappyHexMeshDict;\n}")
	$var_file.puts("\ncastellatedMesh\ttrue;\n")
	$var_file.puts("snap\ttrue;\n")
	$var_file.puts("addLayers\tfalse;\n")
	
	$var_file.puts("\ngeometry\n{")
	
	for p in 0..stlname.length-1 do
		name = stlname[p]
		$var_file.puts("\t"+name+".stl")
		$var_file.puts("\t{")
		$var_file.puts("\t\ttype\ttriSurfaceMesh;")
		$var_file.puts("\t\tname\t"+name+";")
		$var_file.puts("\t\tregions")
		$var_file.puts("\t\t{")
		$var_file.puts("\t\t\t"+name)
		$var_file.puts("\t\t\t{")
		$var_file.puts("\t\t\t\tname\t"+name+"_"+name+";")
		$var_file.puts("\t\t\t}")
		$var_file.puts("\t\t}")
		$var_file.puts("\t}")
	end
	
	for p in 0..refname.length-1 do
		name = refname[p]
		$var_file.puts(name)
		$var_file.puts("\t{")
		$var_file.puts("\t\ttype\tsearchableBox;")
		minX = localBounds[p].corner(0)[0].to_f*0.0254;
		minY = localBounds[p].corner(0)[1].to_f*0.0254;
		minZ = localBounds[p].corner(0)[2].to_f*0.0254;
		maxX = localBounds[p].corner(7)[0].to_f*0.0254;
		maxY = localBounds[p].corner(7)[1].to_f*0.0254;
		maxZ = localBounds[p].corner(7)[2].to_f*0.0254;
		$var_file.puts("\t\tmin\t("+minX.to_s+" "+minY.to_s+" "+minZ.to_s+");")
		$var_file.puts("\t\tmin\t("+maxX.to_s+" "+maxY.to_s+" "+maxZ.to_s+");")
		$var_file.puts("\t}")
	end
	
	$var_file.puts("}")
	
	minX = $bounds.corner(0)[0].to_f*0.0254;
	minY = $bounds.corner(0)[1].to_f*0.0254;
	minZ = $bounds.corner(0)[2].to_f*0.0254;
	maxX = $bounds.corner(7)[0].to_f*0.0254;
	maxY = $bounds.corner(7)[1].to_f*0.0254;
	maxZ = $bounds.corner(7)[2].to_f*0.0254;
	
	avgX = 0.5*(minX + maxX)
	avgY = 0.5*(minY + maxY)
	avgZ = 0.5*(minZ + maxZ)
	
	$var_file.puts("castellatedMeshControls")
	$var_file.puts("{")
	$var_file.puts("\tlocationInMesh\t("+avgX.to_s+" "+avgY.to_s+" "+avgZ.to_s+");")
	$var_file.puts("\tmaxLocalCells\t6000000;")
	$var_file.puts("\tmaxGlobalCells\t20000000;")
	$var_file.puts("\tminRefinementCells\t50;")
	$var_file.puts("\tnCellsBetweenLevels\t3;")
	$var_file.puts("\tresolveFeatureAngle\t60;")
	$var_file.puts("\tallowFreeStandingZoneFaces\tfalse;")
	$var_file.puts("\tfeatures\n\t(\n\t\t{")
	
	for p in 0..stlname.length-1 do
		name = stlname[p]
		$var_file.puts("\t\t\tfile\t\""+name+".eMesh\";")
		$var_file.puts("\t\t\tlevel\t2;")
	end 
	
	$var_file.puts("\t\t}")
	$var_file.puts("\t);")
	
	$var_file.puts("\trefinementSurfaces\n\t{")
	
	for p in 0..stlname.length-1 do
		name = stlname[p]
		$var_file.puts("\t\t"+name)
		$var_file.puts("\t\t{")
		$var_file.puts("\t\t\tlevel\t(2 3);")
		$var_file.puts("\t\t\tregions")
		$var_file.puts("\t\t\t{")
		$var_file.puts("\t\t\t\t"+name+"_"+name)
		$var_file.puts("\t\t\t\t{")
		$var_file.puts("\t\t\t\t\tlevel\t(4 5);")
		$var_file.puts("\t\t\t\t\tpatchInfo")
		$var_file.puts("\t\t\t\t\t{")
		$var_file.puts("\t\t\t\t\t\ttype\twall;")
		$var_file.puts("\t\t\t\t\t}")
		$var_file.puts("\t\t\t\t}")
		$var_file.puts("\t\t\t}")
		$var_file.puts("\t\t}")
	end 
	
	$var_file.puts("\t}")
	
	$var_file.puts("\trefinementRegions\n\t{")
	
	for p in 0..refname.length-1 do
		name = refname[p]
		$var_file.puts("\t\t"+name)
		$var_file.puts("\t\t{")
		$var_file.puts("\t\t\tmode\tinside;")
		$var_file.puts("\t\t\tlevel\t(1.00 3);")
		$var_file.puts("\t\t\}")
	end 
	
	$var_file.puts("\t}")
	$var_file.puts("}")
	
	$var_file.puts("snapControls\n{")
	$var_file.puts("\tnSmoothPatch\t2;")
	$var_file.puts("\ttolerance\t4;")
	$var_file.puts("\tnSolveIter\t20;")
	$var_file.puts("\tnRelaxIter\t4;")
	$var_file.puts("\tnFeatureSnapIter\t10;")
	$var_file.puts("}")
	
	$var_file.puts("addLayersControls\n{")
	$var_file.puts("\trelativeSizes\ttrue;")
	$var_file.puts("\texpansionRatio\t1.3;")
	$var_file.puts("\tfinalLayerThickness\t0.4;")
	$var_file.puts("\tminThickness\t0.3;")
	$var_file.puts("\tnGrow\t0;")
	$var_file.puts("\tfeatureAngle\t45;")
	$var_file.puts("\tnRelaxIter\t4;")
	$var_file.puts("\tnSmoothSurfaceNormals\t1;")
	$var_file.puts("\tnSmoothNormals\t1;")
	$var_file.puts("\tnSmoothThickness\t10;")
	$var_file.puts("\tmaxFaceThicknessRatio\t0.4;")
	$var_file.puts("\tmaxThicknesstoMedialRatio\t4;")
	$var_file.puts("\tminMedianAxisAngle\t130;")
	$var_file.puts("\tnBufferCellsNoExtrude\t0;")
	$var_file.puts("\tnLayerIter\t30;")
	$var_file.puts("\tlayers\n\t{")
	
	for p in 0..stlname.length-1 do
		name = stlname[p]
		$var_file.puts("\t\t"+name)
		$var_file.puts("\t\t{")
		$var_file.puts("\t\t\tnSurfaceLayers\t2;")
		$var_file.puts("\t\t\}")
	end 
	
	$var_file.puts("\t}")
	$var_file.puts("}")
	
	$var_file.puts("meshQualityControls\n{")
	$var_file.puts("\tmaxNonOrtho\t65;")
	$var_file.puts("\tmaxBoundarySkewness\t20;")
	$var_file.puts("\tmaxInternalSkewness\t4;")
	$var_file.puts("\tmaxConcave\t80;")
	$var_file.puts("\tminFlatness\t0.5;")
	$var_file.puts("\tminVol\t1E-13;")
	$var_file.puts("\tminArea\t1E-13;")
	$var_file.puts("\tminTwist\t0.05;")
	$var_file.puts("\tminDeterminant\t0.001;")
	$var_file.puts("\tminFaceWeight\t0.06;")
	$var_file.puts("\tminVolRatio\t0.025;")
	$var_file.puts("\tminTriangleTwist\t-0.99;")
	$var_file.puts("\tnSmoothScale\t4;")
	$var_file.puts("\terrorReduction\t0.75;")
	$var_file.puts("\tminTetQuality\t1E-30;")
	$var_file.puts("}")
	
	$var_file.puts("debug\t0;")
	$var_file.puts("mergeTolerance\t1E-05;")
	$var_file.close
end # end function

def controlDict_create
   	# controlDict
	$var_file = File.new($cwd + "/case/system/controlDict", "w")
	header
	$var_file.puts("\tclass\tdictionary;\n")
	$var_file.puts("\tlocation\tsystem;\n")
	$var_file.puts("\tobject\tcontrolDict;\n}")
	
	$var_file.puts("application\tsimpleFoam;")
	$var_file.puts("startFrom\tlatestTime;")
	$var_file.puts("startTime\t0;")
	$var_file.puts("stopAt\tendTime;")
	$var_file.puts("endTime\t1000;")
	$var_file.puts("deltaT\t1;")
	$var_file.puts("writeControl\ttimeStep;")
	$var_file.puts("writeInterval\t100;")
	$var_file.puts("purgeWrite\t0;")
	$var_file.puts("writeFormat\tascii;")
	$var_file.puts("writePrecision\t6;")
	$var_file.puts("writeCompression\tcompressed;")
	$var_file.puts("timeFormat\tgeneral;")
	$var_file.puts("timePrecision\t6;")
	$var_file.puts("runTimeModifiable\ttrue;")
		
	$var_file.close
end

def decomposePar_create
	# decomposeParDict
	$var_file = File.new($cwd + "/case/system/decomposeParDict", "w")
	header
	$var_file.puts("\tclass\tdictionary;\n")
	$var_file.puts("\tlocation\tsystem;\n")
	$var_file.puts("\tobject\tdecomposeParDict;\n}")
	
	$var_file.puts("numberOfSubdomains\t1;")
	
	$var_file.puts("\nmethod\thierarchical;")
	
	$var_file.puts("\nsimpleCoeffs\n{")
	$var_file.puts("\tn\t(1 1 1);")
	$var_file.puts("\tdelta\t0.001;\n}")
	
	$var_file.puts("\nhierarchicalCoeffs\n{")
	$var_file.puts("\tn\t(1 1 1);")
	$var_file.puts("\tdelta\t0.001;")
	$var_file.puts("\torder\txyz;\n}")
	
	$var_file.puts("\nmanualCoeffs\n{")
	$var_file.puts("\tdataFile\t\"\";")
	$var_file.puts("\tdelta\t0.001;")
	$var_file.puts("\torder\txyz;\n}")

	$var_file.close
end

def fvSchemes_create
	# fvSchemes
	$var_file = File.new($cwd + "/case/system/fvSchemes", "w")
	header
	$var_file.puts("\tclass\tdictionary;\n")
	$var_file.puts("\tlocation\tsystem;\n")
	$var_file.puts("\tobject\tfvSchemes;\n}")
	
	$var_file.puts("\n")
	$var_file.puts("\nddtSchemes\n{")
	$var_file.puts("\tdefault\tsteadyState;")
	$var_file.puts("}")
	
	$var_file.puts("\ngradSchemes\n{")
	$var_file.puts("\tdefault\tGauss Linear;")
	$var_file.puts("}")

	$var_file.puts("\ndivSchemes\n{")
	$var_file.puts("\tdefault\tnone;")
	$var_file.puts("\tdiv(phi,U)\tGauss upwind;")
	$var_file.puts("\tdiv(phi,T)\tGauss upwind;")
	$var_file.puts("\tdiv(phi,k)\tGauss upwind;")
	$var_file.puts("\tdiv(phi,epsilon)\tGauss upwind;")
	$var_file.puts("\tdiv(phi,omega)\tGauss upwind;")
	$var_file.puts("\tdiv((nuEff*dev(T(grad(U)))))\tGauss linear;")
	$var_file.puts("}")
	
	$var_file.puts("\nlaplacianSchemes\n{")
	$var_file.puts("\tdefault\tnone;")
	$var_file.puts("\tlaplacian(nuEff,U)\tGauss linear corrected;")
	$var_file.puts("\tlaplacian(kappaEff,T)\tGauss linear corrected;")
	$var_file.puts("\tlaplacian(DkEff,k)\tGauss linear corrected;")
	$var_file.puts("\tlaplacian(DepsilonEff,epsilon)\tGauss linear corrected;")
	$var_file.puts("\tlaplacian(DomegaEff,omega)\tGauss linear corrected;")
	$var_file.puts("\tlaplacian((1|A(U)),p)\tGauss linear corrected;")
	$var_file.puts("\tlaplacian((1|A(U)),p_rgh)\tGauss linear corrected;")
	$var_file.puts("}")
	
	$var_file.puts("\ninterpolationSchemes\n{")
	$var_file.puts("\tdefault\tlinear;")
	$var_file.puts("}")
	
	$var_file.puts("\nsnGradSchemes\n{")
	$var_file.puts("\tdefault\tcorrected;")
	$var_file.puts("}")
	
	$var_file.puts("\nfluxRequired\n{")
	$var_file.puts("\tdefault\tno;")
	$var_file.puts("\tp\t;")
	$var_file.puts("\tp_rgh\t;")
	$var_file.puts("}")
	
	$var_file.close
end

def fvSolution_create
	# fvSolution
	$var_file = File.new($cwd + "/case/system/fvSolution", "w")
	header
	$var_file.puts("\tclass\tdictionary;\n")
	$var_file.puts("\tlocation\tsystem;\n")
	$var_file.puts("\tobject\tfvSolution;\n}")
	
	$var_file.puts("\n")
	$var_file.puts("\nsolvers\n{")
	$var_file.puts("\t\"p|p_rgh\"\n\t{")
	$var_file.puts("\t\tsolver\tGAMG;")
	$var_file.puts("\t\tsmoother\tGaussSeidel;")
	$var_file.puts("\t\ttolerance\t1e-08;")
	$var_file.puts("\t\trelTol\t0.05;")
	$var_file.puts("\t\tcacheAgglomeration\toff;")
	$var_file.puts("\t\tnCellsInCoarsestLevel\t20;")
	$var_file.puts("\t\tagglomerator\tfaceAreaPair;")
	$var_file.puts("\t\tmergeLevels\t1;")
	$var_file.puts("\t}")
	
	$var_file.puts("\t\"k|omega|epsilon|T|U\"\n\t{")
	$var_file.puts("\t\tsolver\tPBiCG;")
	$var_file.puts("\t\tpreconditioner\tDILU;")
	$var_file.puts("\t\ttolerance\t1e-05;")
	$var_file.puts("\t\trelTol\t0.1;")
	$var_file.puts("\t}")
	
	$var_file.puts("}")
	
	$var_file.puts("\nSIMPLE\n{")
	$var_file.puts("\tnNonOrthogonalCorrectors\t0;")
	$var_file.puts("\tpRefCell\t0;")
	$var_file.puts("\tpRefValue\t0;")
	$var_file.puts("\tresidualControl\n\t{")
	$var_file.puts("\t\t\"k|omega|epsilon|U|T\"\t1e-4;")
	$var_file.puts("\t\t\"p|p_rgh\"\t1e-3;")
	$var_file.puts("\t}\n}")
	
	$var_file.puts("\nrelaxationFactors\n{")
	$var_file.puts("\tequations\n\t{")
	$var_file.puts("\t\t\"k|omega|epsilon|U|T\"\t0.3;")
	$var_file.puts("\t}")
	$var_file.puts("\tfields\n\t{")
	$var_file.puts("\t\t\"p|p_rgh\"\t0.7;")
	$var_file.puts("\t}\n}")
			
	$var_file.close
end

if( not file_loaded?("eofv_skp.rb") )
   add_separator_to_menu("Tools")
   UI.menu("Tools").add_item("Export to OpenFOAM") { skp_of_export }
end

file_loaded("eofv_skp.rb")
