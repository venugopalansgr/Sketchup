# SketchUp to STL
# Create STL file with multiple solids (each of which is a Sketchup group)
# Adapted from: SketchUp to DXF STL Converter 
# Original Creators: Nathan Bromham, Konrad Shroeder
# Adapted by: Venugopalan Raghavan

require 'sketchup.rb'

def group_stl_export
    model = Sketchup.active_model
    model_filename = File.basename(model.path)
	  entities = model.entities
    if( model_filename == "" )
		model_filename = "model"
    end
    $stl_conv = 1.0
    $group_count = 0
    if (Sketchup.version_number==7)
		model.start_operation("export_stl",true)
    else
		model.start_operation("export_stl")
    end
   
	#get units for export
    stl_units_dialog
    stl_option = "stl"
    file_type="stl"
    #exported file name
    out_name = UI.savepanel( file_type+" file location", "." , "#{File.basename(model.path).split(".")[0]}." +file_type )
    $mesh_file = File.new( out_name , "w" )  
        
	UI.messagebox("Number of entities = #{entities.length}",MB_OK)
		
	for p in 0..entities.length-1 do
		entity = entities[p]
		if entity.typename == "Group"
			if entity.name == ""
				entity.name="GROUP"+$group_count.to_s
				$group_count+=1
			end
		end
	end
	
	for p in 0..entities.length-1 do
		entity = entities[p]
		model_name = entity.name
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
	end # end for
	$mesh_file.close
	model.commit_operation
end # end function

def stl_units_dialog
   cu=Sketchup.active_model.options[0]["LengthUnit"]
   case cu
   when 4
      current_unit= "Meters"
   when 3
      current_unit= "Centimeters"
   when 2
      current_unit= "Millimeters"
   when 1
      current_unit= "Feet"
   when 0
      current_unit= "Inches"
   end
   units_list=["Meters","Centimeters","Millimeters","Inches","Feet"].join("|")
   prompts=["Units to export in? (Default is in inches)"]
   enums=[units_list]
   values=[current_unit]
   results = inputbox prompts, values, enums, "Units to export in?"
   return if not results
   case results[0]
   when "Meters"
      $stl_conv=0.0254
   when "Centimeters"
      $stl_conv=2.54
   when "Millimeters"
      $stl_conv=25.4
   when "Feet"
      $stl_conv=0.0833333333333333
   when "Inches"
      $stl_conv=1
   end
end

if( not file_loaded?("skp_to_grpstl.rb") )
   add_separator_to_menu("Tools")
   UI.menu("Tools").add_item("Group STL Export") { group_stl_export }
end

file_loaded("skp_to_grpstl.rb")
