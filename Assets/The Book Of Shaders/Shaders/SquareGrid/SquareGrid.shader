Shader "Custom/SquareGrid" {

    Properties {
        _Tint ("Tint", Color) = (0.5, 0.5, 0.5, 0.5)
    }

    SubShader {
        Tags { "RenderType"="Opaque" }

        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            #define TWO_PI 6.28318530718
            #define PI     3.14159265359

            float4 _Tint;

            struct appdata {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            float mod(float x, float y){
                return x - y * floor(x / y);
            }

            struct squareData{
                float2 uv; // uv of each sqr
                float2 id; // id of each sqr
                float d;   // distance from center
                float r;   // polar angle
            };

            squareData squareCoords(float2 uv){
                squareData res;

                res.uv = frac(uv);
                res.uv = res.uv * 2.0 - 1.0;

                // === MOVEMENT PART ONLY FOR THIS PROJECT ===


                // ===          DELETE IF NEEDED           ===

                res.id = ceil(uv);
                res.d = length(res.uv);
                res.r = (atan2(-res.uv.x, -res.uv.y) / TWO_PI) + 0.5;

                return res;
            }

            v2f vert (appdata v) {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target{

                // coordinates;
                float2 uvNorm = i.uv * 2.0 - 1.0;

                float N = 10.0;
                float2 uvs = i.uv * N;
                float hor = (mod(floor(uvs.y), 2.0) == 0.0 ? 1.0 : 0.0);
                float ver = (mod(floor(uvs.x), 2.0) == 0.0 ? 1.0 : 0.0);
                float2 uvMove = float2(
                    i.uv.x + hor * (smoothstep(0.0, 1.0, mod(_Time.y, 8.0))       - smoothstep(4.0, 5.0, mod(_Time.y, 8.0))) * 0.1,
                    i.uv.y + ver * (smoothstep(0.0, 1.0, mod(_Time.y - 2.0, 8.0)) - smoothstep(4.0, 5.0, mod(_Time.y - 2.0, 8.0))) * 0.1
                    );
                squareData sqr = squareCoords(uvMove * N);

                // base color
                float3 col = float3(0.0, 0.0, 0.0);

                // circles
                float circles = 1.0 - smoothstep(0.6, 0.61, sqr.d);
                //col += circles.xxx;

                col.rg += sqr.uv;

                return float4(col, 1.0);
            }

            ENDCG
        }
    }
}
