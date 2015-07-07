# Sketchup Cartesian grid creator
# Converts each group in a Sketchup file into a Cartesian approximation solid
# Usage: Copy the plugin and place it in the Plugins folder
# Usage: Create your geometry in SketchUp. Note that the geometry must be in GROUP (number of groups is immaterial)
# Usage: Choose "Cartesianize" under Tools menu
# Output: All blocks within a geometry will be in layer 'Internal'
# Output: All blocks outside the above geometry but within bounding box of group will be in layer 'External'
# Limitations: Uses the top surface as the polygon to test if points inside or not and extrudes till base of bounding box
# Limitations: Does not use grading => constant size blocks determined solely by number of divisions
# Limitations: Code seems slightly slow to run. Tips for performance improvement appreciated
# Notes: No warranty on results. Use at your own risk/discretion
# Notes: Code is free. Appreciate feedback/acknowledging when using it
# Created by: Venugopalan Raghavan

# Update 07 Jul 2015: Amended "if" condition in line 109 with additional paranthesis. 
# Update 07 Jul 2015: Original would lead to fvert always being empty

require 'sketchup.rb'

def cartize
	model = Sketchup.active_model
	entities = model.entities
	eps = 1e-6
	layers = model.layers
	pi = Math::PI
	
	# Prompt for number of divisions along each axis
	prompts = ["Along Red Axis?", "Along Green Axis?", "Along Blue Axis?"]
	defaults = ["15", "15", "15"]
	input = UI.inputbox(prompts, defaults, "Specify number of divisions.")
	nX = input[0].to_i
	nY = input[1].to_i
	nZ = input[2].to_i
	
	for p in 0..entities.length-1 do
		entity = entities[p]
		if (entity.typename == "Group")
			bb = entity.bounds
			sX = bb.corner(0).x
			sY = bb.corner(0).y
			sZ = bb.corner(0).z
			eX = bb.corner(0).x
			eY = bb.corner(0).y
			eZ = bb.corner(0).z
			
			# Get bounds of the group's bounding box
			for a in 1..7 do
				sX = sX < bb.corner(a).x ? sX : bb.corner(a).x
				sY = sY < bb.corner(a).y ? sY : bb.corner(a).y
				sZ = sZ < bb.corner(a).z ? sZ : bb.corner(a).z
				eX = eX > bb.corner(a).x ? eX : bb.corner(a).x
				eY = eY > bb.corner(a).y ? eY : bb.corner(a).y
				eZ = eZ > bb.corner(a).z ? eZ : bb.corner(a).z
			end
			
			lX = eX - sX
			lY = eY - sY
			lZ = eZ - sZ
	
			dX = lX/nX
			dY = lY/nY
			dZ = lZ/nZ
			
			xList = []
			yList = []
			zList = []
			
			# Get points defining each block in Cartesian grid
			
			for i in 0..nX do
				xList << sX + i*dX
			end
			for i in 0..nY do
				yList << sY + i*dY
			end
			for i in 0..nZ do
				zList << sZ + i*dZ
			end
			
			cc = []
			ccind = []
			
			# Get cell center for each block in Cartesian grid
			
			for k in 0..nZ-1 do
				ccz = (zList[k]+zList[k+1])/2
				for l in 0..nY-1 do
					ccy = (yList[l]+yList[l+1])/2
					for m in 0..nX-1 do
						ccx = (xList[m]+xList[m+1])/2
						cc << [ccx,ccy,ccz]
						ccind << [m,l,k]
					end
				end
			end
			
			ety = entity.entities
			fcnt = 0
			cX = 0
			cY = 0
			cZ = 0
			fvert = []
			ss = []
			for q in 0..ety.length-1 do
				e = ety[q]
				if e.typename=="Face"
					fcnt = fcnt + 1
					for a in 0..e.vertices.length-1 do 
						ss << [e.vertices[a].position[0],e.vertices[a].position[1],e.vertices[a].position[2]]
						if ((fvert.include? (ss[0])) == false)
							fvert <<(ss[0])
						end
						ss = []
					end
					
				end
			end
			
			maxZ = fvert[0][2] + sZ
			minZ = fvert[0][2] + sZ
			
			for a in 0..fvert.length-1 do
				fvert[a][0] = fvert[a][0] + sX
				fvert[a][1] = fvert[a][1] + sY
				fvert[a][2] = fvert[a][2] + sZ
				maxZ = (maxZ > fvert[a][2]) ? maxZ : fvert[a][2]
				minZ = (minZ < fvert[a][2]) ? minZ : fvert[a][2]
			end
			
			# Check if the face chosen has Z-axis as normal & is the top surface
			
			for q in 0..ety.length-1 do
				e = ety[q]
				if e.typename=="Face"
					d = e.normal.dot Geom::Vector3d.new([0,0,1])
					if (d.abs == 1.0)
						if (((e.vertices[0].position[2]+sZ)-maxZ).abs < 1e-3)
							fface = q
							break
						end
					end
				end
			end
			
			layers.add "Internal"
			layers.add "External"
			
			ffpts = []
			
			for a in 0..ety[fface].vertices.length-1 do
				x = ety[fface].vertices[a].position[0] + sX
				y = ety[fface].vertices[a].position[1] + sY
				z = ety[fface].vertices[a].position[2] + sZ
				ffpts << [x,y,z]
			end
				
			# Ignore z coordinate and check if the centroid lies within the top surface
			# If it lies within, then draw it in layer "Internal"
			# If it lies outside, then draw it in layer "External"
				
			for b in 0..cc.length-1 do
				yes = false
				xcurr = cc[b][0]
				ycurr = cc[b][1]
				
				zcurr = maxZ
							
				pp = Geom::Point3d.new([xcurr,ycurr,zcurr])
				
				yes = Geom.point_in_polygon_2D(pp,ffpts,true)
				
				m = ccind[b][0]
				l = ccind[b][1]
				k = ccind[b][2]
				
				if yes == true
					model.active_layer = "Internal"
				else
					model.active_layer = "External"
				end
				
				p1 = [xList[m],yList[l],zList[k]]
				p2 = [xList[m+1],yList[l],zList[k]]
				p3 = [xList[m+1],yList[l+1],zList[k]]
				p4 = [xList[m],yList[l+1],zList[k]]
				p5 = [xList[m],yList[l],zList[k+1]]
				p6 = [xList[m+1],yList[l],zList[k+1]]
				p7 = [xList[m+1],yList[l+1],zList[k+1]]
				p8 = [xList[m],yList[l+1],zList[k+1]]
				
				model.entities.add_face([p1,p2,p3,p4])
				model.entities.add_face([p1,p2,p6,p5])
				model.entities.add_face([p2,p3,p7,p6])
				model.entities.add_face([p3,p4,p8,p7])
				model.entities.add_face([p1,p4,p8,p5])
				model.entities.add_face([p5,p6,p7,p8])
				
			end
		end
	end
	model.active_layer = "Layer0"
end

if( not file_loaded?("cartize.rb") )
   add_separator_to_menu("Tools")
   UI.menu("Tools").add_item("Cartesianize") { cartize }
end

file_loaded("cartize.rb")
				
