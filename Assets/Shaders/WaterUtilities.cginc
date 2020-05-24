sampler2D _CameraDepthTexture;
sampler2D _WaterBackground;
float4 _CameraDepthTexture_TexelSize;

float3 _WaterFogColor;
float _WaterFogDensity;

float _Tiling;
float _FlowOffset;
float2 _UVJump;

fixed4 _FoamColor;
float _RefractionStrength;

float _CausticsSplit;
float _CausticsDepth;

float3 UnpackDerivativeHeight (float4 textureData) 
{
	float3 dh = textureData.agb;
	dh.xy = dh.xy * 2 - 1;
    
    return dh;
}

float3 CausticsSample (sampler2D causticsMap, float2 mainTexUV, float4 causticsST, float causticsSpeed)
{
    float2 lightXZDir = normalize(_WorldSpaceLightPos0.xz);
	fixed2 uv = mainTexUV * causticsST.xy + causticsST.zw;
    uv += lightXZDir * causticsSpeed * _Time.y;

    fixed r = tex2D(causticsMap, uv + fixed2(+_CausticsSplit, +_CausticsSplit)).r;
	fixed g = tex2D(causticsMap, uv + fixed2(+_CausticsSplit, -_CausticsSplit)).g;
	fixed b = tex2D(causticsMap, uv + fixed2(-_CausticsSplit, -_CausticsSplit)).b;

    return float3(r, g, b);
}

float3 GerstnerWave (float4 wave, float3 p, inout float3 tangent, inout float3 binormal) 
{
    float steepness = wave.z;
    float wavelength = wave.w;
    float2 dir = normalize(wave.xy);
    
    float k = 2 * UNITY_PI / wavelength;
    float c = sqrt(9.8 / k);
    float f = k * (dot(dir, p.xz) - c * _Time.y);
    float a = steepness / k;

    tangent += float3
    (
        -dir.x * dir.x * (steepness * sin(f)),
        dir.x * (steepness * cos(f)),
        -dir.x * dir.y * (steepness * sin(f))
    );

    binormal += float3
    (
        -dir.x * dir.y * (steepness * sin(f)),
        dir.y * (steepness * cos(f)),
        -dir.y * dir.y * (steepness * sin(f))
    );

    return float3
    (
        dir.x * (a * cos(f)),
        a * sin(f),
        dir.y * (a * cos(f))
    );
}

float3 FlowUVW (float2 uv, float2 flowVector, float time, float phaseOffset) 
{
	float progress = frac(time + phaseOffset);
	float3 uvw;
	uvw.xy = uv - flowVector * (progress + _FlowOffset);
	uvw.xy *= _Tiling;
	uvw.xy += phaseOffset;
	uvw.xy += (time - progress) * _UVJump;
	uvw.z = 1 - abs(1 - 2 * progress);

	return uvw;
}

float2 DirectionalFlowUV(float2 uv, float3 flowVectorAndSpeed, float tiling, float time, out float2x2 rotation)
{
	float2 dir = normalize(flowVectorAndSpeed.xy);
	rotation = float2x2(dir.y, dir.x, -dir.x, dir.y);
	uv = mul(float2x2(dir.y, -dir.x, dir.x, dir.y), uv);
	uv.y -= time * flowVectorAndSpeed.z;

	return uv * tiling;
}

float2 AlignWithGrabTexel (float2 uv) 
{
#if UNITY_UV_STARTS_AT_TOP
		if (_CameraDepthTexture_TexelSize.y < 0) 
		{
			uv.y = 1 - uv.y;
		}
#endif

	return (floor(uv * _CameraDepthTexture_TexelSize.zw) + 0.5) * abs(_CameraDepthTexture_TexelSize.xy);
}

float3 DepthWaterColor (float4 screenPos, float3 tangentSpaceNormal, fixed3 foam, fixed3 caustics) 
{
	float2 uvOffset = tangentSpaceNormal.xy * _RefractionStrength;
	uvOffset.y *= _CameraDepthTexture_TexelSize.z * abs(_CameraDepthTexture_TexelSize.y);
	float2 uv = AlignWithGrabTexel((screenPos.xy + uvOffset) / screenPos.w);
	
	float backgroundDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv));
	float surfaceDepth = UNITY_Z_0_FAR_FROM_CLIPSPACE(screenPos.z);
	float depthDifference = backgroundDepth - surfaceDepth;
	
	uvOffset *= saturate(depthDifference);
	uv = AlignWithGrabTexel((screenPos.xy + uvOffset) / screenPos.w);
	backgroundDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv));
	depthDifference = backgroundDepth - surfaceDepth;
	
	float3 backgroundColor = tex2D(_WaterBackground, uv).rgb;
	float fogFactor = saturate(exp2(-_WaterFogDensity * depthDifference));
	float3 depthWaterColor = lerp(_WaterFogColor, backgroundColor, fogFactor); 

	float causticsFactor = saturate(exp2(-_CausticsDepth * depthDifference));
	float3 causticsColor = causticsFactor * caustics;
	depthWaterColor += causticsColor;
	
	float interSectionFoamFactor = saturate(exp2(-depthDifference));	
	float3 finalColor = depthWaterColor + _FoamColor * interSectionFoamFactor * foam;
	
	return finalColor;
}
