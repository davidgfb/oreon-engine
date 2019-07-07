package org.oreon.core.instanced;

import java.util.ArrayList;
import java.util.List;

import org.oreon.core.context.BaseContext;
import org.oreon.core.math.Matrix4f;
import org.oreon.core.math.Vec3f;
import org.oreon.core.scenegraph.RenderList;
import org.oreon.core.scenegraph.Renderable;
import org.oreon.core.util.IntegerReference;

import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public abstract class InstancedObject extends Renderable{
	
	private int instanceCount;
	private Vec3f[] positions;
	
	private List<Matrix4f> worldMatrices = new ArrayList<Matrix4f>();
	private List<Matrix4f> modelMatrices = new ArrayList<Matrix4f>();
	
	private List<Integer> highPolyIndices = new ArrayList<Integer>();
	private List<Integer> lowPolyIndices = new ArrayList<Integer>();
	
	private IntegerReference highPolyInstanceCount;
	private IntegerReference lowPolyInstanceCount;
	private int highPolyRange;
	
	public void update(){
		
		getHighPolyIndices().clear();
		
		int index = 0;
		
		for (Matrix4f transform : getWorldMatrices()){
			if (transform.getTranslation().sub(BaseContext.getCamera().getPosition()).length() < highPolyRange){
				getHighPolyIndices().add(index);
			}

			index++;
		}
		getHighPolyInstanceCount().setValue(getHighPolyIndices().size());
	}
	
	public void record(RenderList renderList){

		if (render){
			if (!renderList.contains(id)){
				renderList.add(this);
				renderList.setChanged(true);
			}
		}
		else {
			if (renderList.contains(id)){
				renderList.remove(this);
				renderList.setChanged(true);
			}
		}
	}
}