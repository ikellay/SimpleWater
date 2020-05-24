Shader "Custom/Water" 
{
    Properties 
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        [NoScaleOffset] _FlowMap ("Flow (RG, A noise)", 2D) = "black" {}
        [NoScaleOffset] _DerivativeHeightMap ("Derivative (AG) Height (B)", 2D) = "black" {}
        _UVJump ("UV jump (XY)", Vector) = (0.24, 0.21, 0, 0)
        _Tiling ("Tiling", Float) = 1
        _Speed ("Speed", Float) = 1
        _FlowStrength ("Flow Strength", Float) = 1
        _FlowOffset ("Flow Offset", Float) = 0
        _HeightScale ("Height Scale, Constant", Float) = 0.25
        _HeightScaleModulated ("Height Scale, Modulated", Float) = 0.75

        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
        
        [Header(Caustics)] 
        _CausticsMap ("Caustics (RGB)", 2D) = "white" {}
        _Caustics_ST_A("Caustics ST A", Vector) = (1,1,0,0)
        _Caustics_ST_B("Caustics ST B", Vector) = (1,1,0,0)
        _CausticsSpeedA ("Caustics Speed A", Float) = 1
        _CausticsSpeedB ("Caustics Speed B", Float) = 1
        _CausticsSplit ("Caustics Split", Float) = 0.006
        _CausticsDepth ("Caustics Depth", Range(0, 2)) = 0.1        

        [Header(Foam)] 
        _FoamMap ("Foam", 2D) = "black" {}
        _FoamColor ("Foam Color", Color) = (1,1,1,1)
                
        [Header(WaterFog)] 
        _WaterFogColor ("Water Fog Color", Color) = (0, 0, 0, 0)
        _WaterFogDensity ("Water Fog Density", Range(0, 2)) = 0.1        

        [Header(Refraction)] 
        _RefractionStrength ("Refraction Strength", Range(0, 1)) = 0.25
        
        [Header(Subsurface Scattering)]
        _SSSDistortion ("Subsurface Scattering Distortion", Float) = 0.4
        _SSSPower ("Subsurface Scattering Power", Float) = 1
        _SSSScale ("Subsurface Scattering Scale", Float) = 1        

        [Header(Waves)]
        _WaveA ("Wave A (dir, steepness, wavelength)", Vector) = (1,0,0.5,10)
        _WaveB ("Wave B", Vector) = (0,1,0.25,20)
        _WaveC ("Wave C", Vector) = (1,1,0.15,10)
    }
    SubShader 
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        
        ZWrite On
        Cull Back
        Colormask 0
        Lighting Off

        CGPROGRAM

        #pragma surface surf Standard vertex:vert nometa
        #include "UnityCG.cginc"
        #include "WaterUtilities.cginc"

        struct Input 
        {
            float2 uv_MainTex;
        };

        float4 _WaveA;
        float4 _WaveB;
        float4 _WaveC;
        
        void vert(inout appdata_full v) 
        {
            float3 vertex = v.vertex.xyz;
            float3 tangent = float3(1, 0, 0);
            float3 binormal = float3(0, 0, 1);
            float3 p = vertex;
            p += GerstnerWave(_WaveA, vertex, tangent, binormal);
            p += GerstnerWave(_WaveB, vertex, tangent, binormal);
            p += GerstnerWave(_WaveC, vertex, tangent, binormal);
            float3 normal = normalize(cross(binormal, tangent));
            v.vertex.xyz = p;
            v.normal = normal;
        }
        
        void surf(Input IN, inout SurfaceOutputStandard o) { }

        ENDCG
        
        GrabPass { "_WaterBackground" }

        CGPROGRAM
        #pragma surface surf StandardTranslucent alpha vertex:vert finalcolor:ResetAlpha
        #pragma target 3.0

        #include "WaterUtilities.cginc"
        #include "UnityPBSLighting.cginc"

        sampler2D _MainTex;
        sampler2D _FlowMap;
        sampler2D _DerivativeHeightMap;
        
        fixed4 _Color;
        half _Glossiness;
        half _Metallic;

        float _Speed;
        float _FlowStrength;
        float _HeightScale;
        float _HeightScaleModulated;

        sampler2D _CausticsMap;
        float4 _Caustics_ST_A;
        float _CausticsSpeedA;
        float4 _Caustics_ST_B;
        float _CausticsSpeedB;
                
        sampler2D _FoamMap;
        
        float _SSSDistortion;
        float _SSSPower;
        float _SSSScale;

        float4 _WaveA;
        float4 _WaveB;
        float4 _WaveC;
        
        struct Input 
        {
            float2 uv_MainTex;
            float4 screenPos;
        };

        void vert(inout appdata_full v) 
        {
            float3 vertex = v.vertex.xyz;
            float3 tangent = float3(1, 0, 0);
            float3 binormal = float3(0, 0, 1);
            float3 p = vertex;
            p += GerstnerWave(_WaveA, vertex, tangent, binormal);
            p += GerstnerWave(_WaveB, vertex, tangent, binormal);
            p += GerstnerWave(_WaveC, vertex, tangent, binormal);
            float3 normal = normalize(cross(binormal, tangent));
            v.vertex.xyz = p;
            v.normal = normal;
        }

        inline fixed4 LightingStandardTranslucent(SurfaceOutputStandard s, fixed3 viewDir, UnityGI gi)
        {            
            fixed4 pbr = LightingStandard(s, viewDir, gi); 
            float3 halfwayDir = normalize(gi.light.dir + s.Normal * _SSSDistortion);
            float subsurfaceScatteringFactor = pow(saturate(dot(viewDir, -halfwayDir)), _SSSPower) * _SSSScale;
             
            pbr.rgb = pbr.rgb + _Color * subsurfaceScatteringFactor;

            return pbr;
        }

        void LightingStandardTranslucent_GI(SurfaceOutputStandard s, UnityGIInput data, inout UnityGI gi)
        {
            LightingStandard_GI(s, data, gi);
        }

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            float3 flow = tex2D(_FlowMap, IN.uv_MainTex).rgb;
            flow.xy = flow.xy * 2 - 1;
            flow *= _FlowStrength;
            float finalHeightScale = flow.z * _HeightScaleModulated + _HeightScale;
            float noise = tex2D(_FlowMap, IN.uv_MainTex).a;
            float time = _Time.y * _Speed + noise;

            float3 uvwA = FlowUVW(IN.uv_MainTex, flow.xy, time, 0);
            float3 uvwB = FlowUVW(IN.uv_MainTex, flow.xy, time, 0.5);
            
            float3 dhA = UnpackDerivativeHeight(tex2D(_DerivativeHeightMap, uvwA.xy)) * (uvwA.z * finalHeightScale);
            float3 dhB = UnpackDerivativeHeight(tex2D(_DerivativeHeightMap, uvwB.xy)) * (uvwB.z * finalHeightScale);
            o.Normal = normalize(float3(-(dhA.xy + dhB.xy), 1));

            fixed4 texA = tex2D(_MainTex, uvwA.xy) * uvwA.z;
            fixed4 texB = tex2D(_MainTex, uvwB.xy) * uvwB.z;

            fixed3 causticsA = CausticsSample(_CausticsMap, IN.uv_MainTex, _Caustics_ST_A, _CausticsSpeedA); 
            fixed3 causticsB = CausticsSample(_CausticsMap, IN.uv_MainTex, _Caustics_ST_B, _CausticsSpeedB);
            fixed3 caustics = min(causticsA, causticsB);

            fixed4 foamA = tex2D(_FoamMap, uvwA.xy) * uvwA.z;
            fixed4 foamB = tex2D(_FoamMap, uvwB.xy) * uvwB.z;
            fixed4 foam = foamA + foamB;

            fixed4 c = (texA + texB) * _Color;
            o.Albedo = c.rgb;
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Alpha = c.a;
            o.Emission = DepthWaterColor(IN.screenPos, o.Normal, foam, caustics) * (1 - c.a);
        }
        
        void ResetAlpha (Input IN, SurfaceOutputStandard o, inout fixed4 color) 
        {
            color.a = 1;
        }
        
        ENDCG
    }
}