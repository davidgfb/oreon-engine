#version 430

in vec2 texCoordF;
in vec4 viewSpacePos;
in vec3 position;
in vec3 tangent;

struct Material
{
	sampler2D diffusemap;
	sampler2D normalmap;
	sampler2D heightmap;
	float displaceScale;
	float shininess;
	float emission;
};

struct Fractal
{
	sampler2D normalmap;
	int scaling;
};

layout (std140, row_major) uniform Camera{
	vec3 eyePosition;
	mat4 m_View;
	mat4 m_ViewProjection;
	vec4 frustumPlanes[6];
};

layout (std140) uniform DirectionalLight{
	vec3 direction;
	float intensity;
	vec3 ambient;
	vec3 color;
} directional_light;

layout (std140, row_major) uniform LightViewProjections{
	mat4 m_lightViewProjection[6];
	float splitRange[6];
};

uniform sampler2DArray shadowMaps;
uniform Fractal fractals1[7];
uniform sampler2D splatmap;
uniform float scaleY;
uniform float scaleXZ;
uniform Material sand;
uniform Material grass;
uniform Material rock;
uniform Material snow;
uniform float sightRangeFactor;
uniform int largeDetailedRange;

const float zFar = 10000;
const vec3 fogColor = vec3(0.62,0.85,0.95);

float emission;
float shininess;

float diffuse(vec3 direction, vec3 normal, float intensity)
{
	return max(0.0, dot(normal, -direction) * intensity);
}

float specular(vec3 direction, vec3 normal, vec3 eyePosition, vec3 vertexPosition)
{
	vec3 reflectionVector = normalize(reflect(direction, normal));
	vec3 vertexToEye = normalize(eyePosition - vertexPosition);
	
	float specular = max(0, dot(vertexToEye, reflectionVector));
	
	return pow(specular, shininess) * emission;
}


float shadow(vec3 worldPos)
{
	float shadow = 1;
	float shadowMapDepth = 0;
	vec3 projCoords = vec3(0,0,0);
	float depth = viewSpacePos.z/zFar;
	if (depth < splitRange[0]){
		vec4 lightSpacePos = m_lightViewProjection[0] * vec4(worldPos,1.0);
		projCoords = lightSpacePos.xyz * 0.5 + 0.5;
		shadowMapDepth = texture(shadowMaps, vec3(projCoords.xy,0)).r; 
	}
	else if (depth < splitRange[1]){
		vec4 lightSpacePos = m_lightViewProjection[1] * vec4(worldPos,1.0);
		projCoords = lightSpacePos.xyz * 0.5 + 0.5;
		shadowMapDepth = texture(shadowMaps, vec3(projCoords.xy,1)).r;  
	}
	else if (depth < splitRange[2]){
		vec4 lightSpacePos = m_lightViewProjection[2] * vec4(worldPos,1.0);
		projCoords = lightSpacePos.xyz * 0.5 + 0.5;
		shadowMapDepth = texture(shadowMaps, vec3(projCoords.xy,2)).r; 
	}
	else if (depth < splitRange[3]){
		vec4 lightSpacePos = m_lightViewProjection[3] * vec4(worldPos,1.0);
		projCoords = lightSpacePos.xyz * 0.5 + 0.5;
		shadowMapDepth = texture(shadowMaps, vec3(projCoords.xy,3)).r; 
	}
	else if (depth < splitRange[4]){
		vec4 lightSpacePos = m_lightViewProjection[4] * vec4(worldPos,1.0);
		projCoords = lightSpacePos.xyz * 0.5 + 0.5;
		shadowMapDepth = texture(shadowMaps, vec3(projCoords.xy,4)).r; 
	}
	else if (depth < splitRange[5]){
		vec4 lightSpacePos = m_lightViewProjection[5] * vec4(worldPos,1.0);
		projCoords = lightSpacePos.xyz * 0.5 + 0.5;
		shadowMapDepth = texture(shadowMaps, vec3(projCoords.xy,5)).r; 
	}
	else return 1;
	
	float currentDepth = projCoords.z;  
	shadow = currentDepth > shadowMapDepth ? 0.25 : 1.0; 
	return shadow;
}

void main()
{		
	float dist = length(eyePosition - position);
	float height = position.y;
	
	// normalmap/occlusionmap/splatmap coords
	vec2 mapCoords = (position.xz + scaleXZ/2)/scaleXZ; 

	vec3 normal = vec3(0,0,0);
	
	normal += (2*(texture(fractals1[0].normalmap, mapCoords*fractals1[0].scaling).rbg)-1);
	normal += (2*(texture(fractals1[1].normalmap, mapCoords*fractals1[1].scaling).rbg)-1);
	normal += (2*(texture(fractals1[2].normalmap, mapCoords*fractals1[2].scaling).rbg)-1);
	normal += (2*(texture(fractals1[3].normalmap, mapCoords*fractals1[3].scaling).rbg)-1);
	normal += (2*(texture(fractals1[4].normalmap, mapCoords*fractals1[4].scaling).rbg)-1);
	normal += (2*(texture(fractals1[5].normalmap, mapCoords*fractals1[5].scaling).rbg)-1);
	normal += (2*(texture(fractals1[6].normalmap, mapCoords*fractals1[6].scaling).rbg)-1);
	normal = normalize(normal);
	
	float snowBlend  = clamp(height/200,0,1);
	float rockBlend = 0;
	if (height <= 300)
		rockBlend  = clamp((height+200)/200,0,1);
	else
		rockBlend = clamp((-height+200)/200,0,1);
	
	float sandBlend  = clamp(-height/200,0,1);
	float grassBlend = clamp((height+200)/-400 + 1,0,1);
	
	if (dist < largeDetailedRange-20)
	{
		float attenuation = -dist/(largeDetailedRange-20) + 1;
		
		vec3 bitangent = normalize(cross(tangent, normal));
		mat3 TBN = mat3(tangent,normal,bitangent);
		
		vec3 bumpNormal = normalize((2*(texture(sand.normalmap, texCoordF).rbg) - 1) * sandBlend
								 +  (2*(texture(rock.normalmap, texCoordF/2).rbg) - 1) * rockBlend
								 +  (2*(texture(snow.normalmap, texCoordF/4).rbg) - 1) * snowBlend);
		
		bumpNormal.xz *= attenuation;
		
		normal = normalize(TBN * bumpNormal);
	}
	
	emission  = grassBlend * grass.emission + sandBlend * sand.emission + rockBlend * rock.emission + snowBlend * snow.emission;
	shininess = grassBlend * grass.shininess + sandBlend * sand.shininess + rockBlend * rock.shininess + snowBlend * snow.shininess;
	
	float diffuse = diffuse(directional_light.direction, normal, directional_light.intensity);
	float specular = specular(directional_light.direction, normal, eyePosition, position);
	vec3 diffuseLight = directional_light.ambient + directional_light.color * diffuse;
	vec3 specularLight = directional_light.color * specular;
	
	vec3 fragColor = mix(texture(sand.diffusemap, texCoordF).rgb, texture(rock.diffusemap, texCoordF/2).rgb, clamp((height+200)/400.0,0,1));
	fragColor = mix(fragColor, texture(snow.diffusemap,texCoordF/4).rgb, clamp((height-100)/200,0,1));
	float grassFactor = clamp((height+100)/(-scaleY)+0.6,0.0,0.9);
	if (normal.y > 0.9){
		fragColor = mix(fragColor,texture(grass.diffusemap,texCoordF).rgb,grassFactor);
	}
	
	fragColor *= diffuseLight;
	fragColor += specularLight;
	fragColor *= shadow(position);
	
	float fogFactor = -0.0005/sightRangeFactor*(dist-zFar/5*sightRangeFactor);
	
    vec3 rgb = mix(fogColor, fragColor, clamp(fogFactor,0,1));
	
	gl_FragColor = vec4(rgb,1);
}