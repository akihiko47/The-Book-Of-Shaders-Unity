Shader "Custom/FlowNoise" {

    Properties {
        _Col1 ("Color 1", Color) = (0.5, 0.5, 0.5, 1.0)
        _Col2 ("Color 2", Color) = (0.5, 0.5, 0.5, 1.0)
        _Col3 ("Color 3", Color) = (0.5, 0.5, 0.5, 1.0)
        _Col4 ("Color 4", Color) = (0.5, 0.5, 0.5, 1.0)
    }

    SubShader {
        Tags { "RenderType"="Opaque" }

        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            float4 _Col1, _Col2, _Col3, _Col4;

            struct appdata {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            float2 rotate(float2 uv, float th){
                return mul(float2x2(cos(th), sin(th), -sin(th), cos(th)), uv);
            }

            // By IQ
            float2 grad(int2 z, float rot){
                int n = z.x + z.y * 11111;

                n = (n << 13) ^ n;
                n = (n * (n * n * 15731 + 789221) + 1376312589) >> 16;

                n &= 7;
                float2 gr = float2(n & 1, n >> 1) * 2.0 - 1.0;
                float2 res = (n >= 6) ? float2(0.0, gr.x) :
                             (n >= 4) ? float2(gr.x, 0.0) :
                             gr;
                return rotate(res, _Time.y * rot);
            }

            // by IQ
            float noise(in float2 p, float rot){
                int2 i = int2(floor(p));
                float2 f = frac(p);

                float2 u = f * f * (3.0 - 2.0 * f);

                return lerp(lerp(dot(grad(i + int2(0, 0), rot), f - float2(0.0, 0.0)),
                                 dot(grad(i + int2(1, 0), rot), f - float2(1.0, 0.0)), u.x),
                            lerp(dot(grad(i + int2(0, 1), rot), f - float2(0.0, 1.0)),
                                 dot(grad(i + int2(1, 1), rot), f - float2(1.0, 1.0)), u.x), u.y);
            }

            #define OCTAVES 6
            float fbm(float2 uv){

                float value = 0.0;
                float amplitude = 0.8;
                float rot = 1.2;

                for(int i = 0; i < OCTAVES; i++){
                    value += amplitude * abs(noise(uv, rot));
                    uv *= 2.0;
                    amplitude *= 0.4;
                    rot *= 1.5;
                }
                return value;
            }

            v2f vert (appdata v) {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target{

                // p      = i.uv
                // result = fbm(p + fbm(p))
                // q      = fbm(p)---this

                // COORDS
                float2 p = i.uv * 5.0;

                // BASE COLOR
                float3 col = 0.0;

                // NOISE
                float2 q;
                q.x = fbm(p + float2(6.9, 0.0));
                q.y = fbm(p + float2(5.2, 1.3));

                float nse = fbm(p + q);

                // CIRCLE
                float dfC = length(i.uv * 2.0 - 1.0) - 0.4 + fbm(i.uv * 20.0) * 0.05;
                float circle = smoothstep(0.02, 0.01, dfC) - smoothstep(-0.01, -0.012, dfC);

                // GLOW
                float glow = saturate(0.001 / pow((dfC - 0.01), 2.0));
                col += glow;

                // FIRE
                float3 fire;
                fire = lerp(_Col1, _Col2, saturate(pow(nse, 1.5)));
                fire = pow(lerp(fire, _Col3, q.y * q.y), 4.0);
                col += glow * fire * 8.0;
                

                return float4(col, 1.0);
            }

            ENDCG
        }
    }
}
