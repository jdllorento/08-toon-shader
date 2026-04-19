Shader "Custom/SimpleToon"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (1, 1, 1, 1)
        _MainTex ("Main Texture", 2D) = "white" {}
        _ShadowThreshold ("Shadow Threshold", Range(0, 1)) = 0.5
        _ShadowSmoothness ("Shadow Smoothness", Range(0, 0.1)) = 0.01
    }
    
    SubShader
    {
        Tags { 
            "RenderType"="Opaque" 
            "RenderPipeline"="UniversalPipeline" 
            "Queue"="Geometry" 
        }

        // Iluminación y recepción de sombras
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : NORMAL;
                float2 uv : TEXCOORD0;
            };

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float _ShadowThreshold;
                float _ShadowSmoothness;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            Varyings vert(Attributes input)
            {
                Varyings output;
                
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, float4(1,1,1,1));

                output.positionCS = vertexInput.positionCS;
                output.positionWS = vertexInput.positionWS;
                output.normalWS = normalInput.normalWS;
                output.uv = input.uv;

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                // Textura y Color Base
                half4 baseColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv) * _BaseColor;

                // Obtener datos de la luz direccional y las sombras proyectadas
                float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                Light mainLight = GetMainLight(shadowCoord);

                // Producto Punto. Cuánta luz recibe la superficie
                float3 normal = normalize(input.normalWS);
                float NdotL = dot(normal, mainLight.direction);

                float halfLambert = NdotL * 0.5 + 0.5;

                // Aplicar la atenuación de las sombras proyectadas por otros objetos
                halfLambert *= mainLight.shadowAttenuation;

                // Crear bandas duras usando smoothstep
                float toonIntensity = smoothstep(_ShadowThreshold - _ShadowSmoothness, 
                                               _ShadowThreshold + _ShadowSmoothness, 
                                               halfLambert);

                // Mezcla final
                half3 lightColor = mainLight.color * toonIntensity;
                half3 ambientLight = half3(0.2, 0.2, 0.2);

                return half4(baseColor.rgb * (lightColor + ambientLight), baseColor.a);
            }
            ENDHLSL
        }

        // Proyectar sombras
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
                
                // Obtenemos los datos de la luz principal para extraer la dirección
                Light light = GetMainLight();
                
                float3 positionCS_WS = ApplyShadowBias(positionWS, normalWS, light.direction);
                output.positionCS = TransformWorldToHClip(positionCS_WS);
                
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                return 0; 
            }
            ENDHLSL
        }
    }
}