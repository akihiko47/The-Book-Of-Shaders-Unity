Shader "RayMarching/RayMarcherBase" {

    Properties {
        _MainTex ("Texture", 2D) = "white" {}
    }

    SubShader {

        Tags { "RenderType" = "Overlay" "Queue" = "Overlay"}

        Cull Off ZWrite Off ZTest Always

        Pass {
            Tags { "LightMode" = "ForwardBase" }

            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile __ RM_SOFT_SHADOWS_ON 
            #pragma multi_compile __ RM_BLEND_ON_SCENE 
            #pragma multi_compile __ RM_POINT_LIGHT_ON
            #pragma multi_compile __ RM_AMB_MAP_ON

            #include "UnityCG.cginc"

            // rendered scene texture
            sampler2D _MainTex;

            // camera values
            uniform float3 _CameraWorldPos;
            uniform float4x4 _FrustumCornersMatrix;
            uniform float4x4 _CameraToWorldMatrix;

            // other values
            uniform float       _MaxDist;
            uniform int         _MaxSteps;
            uniform float       _SurfDist;
            uniform float3      _DirLightDir;
            uniform float4      _DirLightCol;
            uniform float       _DirLightInt;
            uniform float3      _PntLightPos;
            uniform float4      _PntLightCol;
            uniform float       _PntLightInt;
            uniform float       _ShadowsIntensity;
            uniform float       _ShadowsSoftness;
            uniform float2      _ShadowsDistance;
            uniform float       _AoStep;
            uniform float       _AoInt;
            uniform int         _AoIterations;
            uniform float4      _AmbCol;
            uniform samplerCUBE _ReflMap;
            uniform float       _ReflMaxDist;
            uniform int         _MaxRefl;

            // depth texture
            uniform sampler2D _CameraDepthTexture;


            struct appdata {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float2 uvOriginal :TEXCOORD01;
                float3 ray: TEXCOORD2;
            };

            struct material {
                float3 kd;
                float3 ks;
                float  q;           // for Blinn-Phong specular
                float  reflInt;     // for true reflections
                float  ambReflInt;  // for cubemap reflections
            };

            struct hitInfo {
                float d;
                float3 pnt;
                material mat;
            };

            #include "DistanceFunctions.cginc"

            material DefaultMaterial(){
                material res;
                res.kd         = 1.0;
                res.ks         = 1.0;
                res.q          = 100.0;
                res.reflInt    = 0.0;
                res.ambReflInt = 0.0;
                return res;
            }
            
            hitInfo GetDist(float3 p) { 
                hitInfo dS;
                dS.d = sdSphere(p - float3(sin(_Time.y) * 3.0, 1.2, 0.0), 1.0);
                dS.mat = DefaultMaterial();
                dS.mat.kd = float3(0.0, 0.0, 1.0);
                dS.mat.q = 5000.0;
                dS.mat.reflInt = 0.1;
                dS.mat.ambReflInt = 0.05;

                hitInfo dB;
                dB.d = sdRoundBox(p - float3(0.0, 1.2, 0.0), float3(1.0, 1.0, 1.0), 0.2);
                dB.mat = DefaultMaterial();
                dB.mat.kd = float3(1.0, 0.0, 0.0);
                dB.mat.q  = 10.0;

                dB = opUS(dS, dB, 1.0);

                hitInfo dP;
                dP.d = sdPlane(p, normalize(float3(0.0, 1.0, 0.0)));
                dP.mat = DefaultMaterial();
                dP.mat.reflInt = 0.3;
                dP.mat.ambReflInt = 0.0;

                hitInfo res; 
                res = opU(dB,  dP);
                return res;
            }

            float HardShadows(float3 ro, float3 rd, float mint, float maxt){
                float t = mint;
                while(t < maxt){
                    float h = GetDist(ro + rd * t).d;
                    t += h;
                    if(h < _SurfDist) return 0.0;
                }
                return 1.0;
            }

            float SoftShadows(float3 ro, float3 rd, float mint, float maxt, float k){
                float result = 1.0;

                float t = mint;
                while(t < maxt){
                    float h = GetDist(ro + rd * t).d; 
                    t += h;
                    result = min(result, k * h / t);
                    if(h < _SurfDist) return 0.0;
                }
                return result;
            }

            float AmbientOcclusion(float3 p, float3 n){
                float step = _AoStep;
                float ao = 0.0;
                float dist;
                for(int i = 1; i < _AoIterations; i++){
                    dist = step * i;
                    ao += max(0.0, (dist - GetDist(p + n * dist).d) / dist);
                }
                return 1.0 - ao * _AoInt;
            }

            float3 GetNormal(float3 pnt){
                float d = GetDist(pnt).d;
                float2 e = float2(0.001, 0.0);

                float3 n = d - float3(GetDist(pnt - e.xyy).d,
                                      GetDist(pnt - e.yxy).d,
                                      GetDist(pnt - e.yyx).d);

                return normalize(n);
            }

            v2f vert (appdata v){
                v2f o;

                half index = v.vertex.z;
                v.vertex.z = 0.1;
                o.vertex = UnityObjectToClipPos(v.vertex);

                o.uvOriginal = v.uv;  // screen space uvs
                o.uv = v.uv.xy * 2 - 1;

                o.ray = _FrustumCornersMatrix[(int)index].xyz;
                o.ray = mul(_CameraToWorldMatrix, o.ray);
                return o;
            }

            bool RayMarch(float3 ro, float3 rd, float depth, inout hitInfo hit){
                float OriginDistance = _SurfDist;

                for(int n = 0; n < _MaxSteps; n++){
                    float3 p = ro + rd * OriginDistance;
                    hit = GetDist(p);
                    OriginDistance += hit.d;
                    if(hit.d < _SurfDist){
                        hit.pnt = p;
                        return true;
                    }
                    if(OriginDistance > _MaxDist){
                        return false;
                    }
                    #ifdef RM_BLEND_ON_SCENE
                        if(OriginDistance >= depth){
                            return false;
                        }
                    #endif
                };
                return false;
            }

            float3 Shading(hitInfo hit, float3 N){
                float3 color = 0.0;

                // LIGHT
                float3 V = normalize(_CameraWorldPos - hit.pnt);

                #ifdef RM_POINT_LIGHT_ON
                    float3 L = normalize(_PntLightPos - hit.pnt);
                    float3 lightColor = _PntLightCol * _PntLightInt;
                    float3 lightVec = _PntLightPos - hit.pnt;
                    float attenuation = 1 / dot(lightVec, lightVec);
                    lightColor = saturate(lightColor * attenuation);
                #else
                    float3 L = _DirLightDir;
                    float3 lightColor = saturate(_DirLightCol * _DirLightInt);
                #endif
                float3 H = normalize(L + V);

                // Blinn-Phong BRDF

                float  q = hit.mat.q;
                float3 kd = hit.mat.kd;
                float3 ks = hit.mat.ks;
                #ifdef RM_AMB_MAP_ON
                    float3 ka = max(0, ShadeSH9(float4(N, 1.0)));
                #else
                    float3 ka = _AmbCol.rgb;
                #endif 

                color.rgb = (kd * max(0.0, dot(N, L) * 0.5 + 0.5) + ks * pow(max(0.0, dot(N, H)), q)) * lightColor + ka;

                // SHADOWS
                float shadows;
                #ifdef RM_SOFT_SHADOWS_ON
                    shadows = SoftShadows(hit.pnt, L, _ShadowsDistance.x, _ShadowsDistance.y, _ShadowsSoftness) * 0.5 + 0.5;
                #else
                    shadows = HardShadows(hit.pnt, L, _ShadowsDistance.x, _ShadowsDistance.y) * 0.5 + 0.5;
                #endif
                shadows = max(0.0, pow(shadows, _ShadowsIntensity));
                color.rgb *= shadows;

                // FOG
                /*float3 fogColor = float3(1.0, 1.0, 1.0);
                float density = 0.03;
                float fog = pow(2, -pow((dist * density), 2));
                color.rgb = lerp(fogColor, color, fog);*/

                // AMBIENT OCCLUSION
                color.rgb *= AmbientOcclusion(hit.pnt, N);

                return color;
            }

            float4 frag(v2f i) : SV_Target{

                // DEPTH TEXTURE
                float depth = LinearEyeDepth(tex2D(_CameraDepthTexture, i.uvOriginal).r);
                depth *= length(i.ray);  // convert depth to distance

                float3 ro = _CameraWorldPos;
                float3 rd = normalize(i.ray);

                float4 color = float4(0.0, 0.0, 0.0, 0.0);
                
                hitInfo hit;
                if (RayMarch(ro, rd, depth, hit)){
                    color.w = 1.0;

                    float3 N = GetNormal(hit.pnt);
                    float3 R = normalize(reflect(rd, N));
                    color.rgb += Shading(hit, N);

                    // CUBEMAP REFLECTIONS
                    color.rgb += texCUBE(_ReflMap, R).rgb * hit.mat.ambReflInt;

                    // REFLECTION
                    hitInfo hit2;
                    if(RayMarch(hit.pnt + R * 0.01, R, _ReflMaxDist, hit2) && _MaxRefl >= 1){
                        float3 N2 = GetNormal(hit2.pnt);
                        float3 R2 = normalize(reflect(R, N2));

                        // TRUE REFLECTIONS 1
                        color.rgb += Shading(hit2, N2) * hit.mat.reflInt; 

                        // REFLECTION
                        hitInfo hit3;
                        if(RayMarch(hit2.pnt + R2 * 0.01, R2, _ReflMaxDist, hit3) && _MaxRefl >= 2){
                            float3 N3 = GetNormal(hit3.pnt);
                            float3 R3 = normalize(reflect(R2, N3));

                            // TRUE REFLECTIONS 2 
                            color.rgb += Shading(hit3, N3) * hit2.mat.reflInt * hit.mat.reflInt;

                            // REFLECTION
                            hitInfo hit4;
                            if(RayMarch(hit3.pnt + R3 * 0.01, R3, _ReflMaxDist, hit4) && _MaxRefl >= 3){
                                float3 N4 = GetNormal(hit4.pnt);

                                // TRUE REFLECTIONS 3
                                color.rgb += Shading(hit4, N4) * hit3.mat.reflInt * hit2.mat.reflInt * hit.mat.reflInt;
                            }
                        }
                    }

                    
                }

                // BLENDING
                #ifdef RM_BLEND_ON_SCENE
                    float4 originalColor = tex2D(_MainTex, i.uvOriginal);
                    return float4(originalColor * (1.0 - color.w) + color.xyz * color.w, 1.0);
                #else
                    return float4(color.rgb * color.w, 1.0);
                #endif
            }

            ENDCG
        }
    }
}
