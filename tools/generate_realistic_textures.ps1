# Realistik hastane + prop texture seti (C# hizlandirilmis).
# fBm noise tabanli; pistol ve knife texture'larina DOKUNMAZ.
Add-Type -AssemblyName System.Drawing

$root = Join-Path $PSScriptRoot "..\assets\textures"
$hospital = Join-Path $root "hospital"
$props = Join-Path $root "props"
New-Item -ItemType Directory -Force -Path $hospital, $props | Out-Null

$src = @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class TexGen
{
    static int[] perm = new int[512];

    static void InitPerm(int seed)
    {
        var rng = new Random(seed);
        int[] p = new int[256];
        for (int i = 0; i < 256; i++) p[i] = i;
        for (int i = 255; i > 0; i--) { int j = rng.Next(i + 1); int t = p[i]; p[i] = p[j]; p[j] = t; }
        for (int i = 0; i < 512; i++) perm[i] = p[i & 255];
    }

    static double Fade(double t) { return t * t * t * (t * (t * 6 - 15) + 10); }
    static double Lerp(double a, double b, double t) { return a + (b - a) * t; }

    static double ValNoise(double x, double y)
    {
        int xi = (int)Math.Floor(x) & 255;
        int yi = (int)Math.Floor(y) & 255;
        double xf = x - Math.Floor(x);
        double yf = y - Math.Floor(y);
        double u = Fade(xf), v = Fade(yf);
        int aa = perm[perm[xi] + yi];
        int ab = perm[perm[xi] + yi + 1];
        int ba = perm[perm[xi + 1] + yi];
        int bb = perm[perm[xi + 1] + yi + 1];
        double x1 = Lerp(aa / 255.0, ba / 255.0, u);
        double x2 = Lerp(ab / 255.0, bb / 255.0, u);
        return Lerp(x1, x2, v);
    }

    static double Fbm(double x, double y, int oct, double lac, double gain)
    {
        double sum = 0, amp = 0.5, freq = 1, norm = 0;
        for (int o = 0; o < oct; o++)
        {
            sum += amp * ValNoise(x * freq, y * freq);
            norm += amp; amp *= gain; freq *= lac;
        }
        return sum / norm;
    }

    static int Clamp(double v) { return (int)Math.Max(0, Math.Min(255, Math.Round(v))); }

    // BGRA buffer
    static byte[] buf; static int W, H;
    static void NewCanvas(int w, int h) { W = w; H = h; buf = new byte[w * h * 4]; }
    static void Set(int x, int y, double r, double g, double b, int a)
    {
        if (x < 0 || y < 0 || x >= W || y >= H) return;
        int i = (y * W + x) * 4;
        buf[i] = (byte)Clamp(b); buf[i + 1] = (byte)Clamp(g); buf[i + 2] = (byte)Clamp(r); buf[i + 3] = (byte)a;
    }
    static void Blend(int x, int y, double r, double g, double b, double a)
    {
        if (x < 0 || y < 0 || x >= W || y >= H || a <= 0) return;
        if (a > 1) a = 1;
        int i = (y * W + x) * 4;
        double ob = buf[i], og = buf[i + 1], or_ = buf[i + 2];
        buf[i] = (byte)Clamp(ob + (b - ob) * a);
        buf[i + 1] = (byte)Clamp(og + (g - og) * a);
        buf[i + 2] = (byte)Clamp(or_ + (r - or_) * a);
        buf[i + 3] = 255;
    }
    static void Clear(int x, int y) { if (x>=0&&y>=0&&x<W&&y<H) buf[(y*W+x)*4+3]=0; }

    static void Save(string path)
    {
        var bmp = new Bitmap(W, H, PixelFormat.Format32bppArgb);
        var rect = new Rectangle(0, 0, W, H);
        var data = bmp.LockBits(rect, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
        Marshal.Copy(buf, 0, data.Scan0, buf.Length);
        bmp.UnlockBits(data);
        bmp.Save(path, ImageFormat.Png);
        bmp.Dispose();
    }

    static void Disc(double cx, double cy, double rx, double ry, double r, double g, double b, double alpha)
    {
        for (int y = (int)(cy - ry - 1); y <= (int)(cy + ry + 1); y++)
            for (int x = (int)(cx - rx - 1); x <= (int)(cx + rx + 1); x++)
            {
                double dx = (x - cx) / rx, dy = (y - cy) / ry, d = dx * dx + dy * dy;
                if (d <= 1.0) Blend(x, y, r, g, b, alpha * Math.Min(1.0, (1.0 - d) * 4.0));
            }
    }
    static void RectF(int x0, int y0, int x1, int y1, double r, double g, double b, double a)
    {
        for (int y = y0; y <= y1; y++) for (int x = x0; x <= x1; x++) Blend(x, y, r, g, b, a);
    }

    public static void Wall(string path)
    {
        NewCanvas(512, 512); InitPerm(11);
        int tileW = 128, tileH = 170;
        for (int y = 0; y < 512; y++)
            for (int x = 0; x < 512; x++)
            {
                double n = Fbm(x / 90.0, y / 90.0, 5, 2.0, 0.55);
                double fine = Fbm(x / 14.0, y / 14.0, 3, 2.2, 0.5);
                double bas = 58 + (n - 0.5) * 36 + (fine - 0.5) * 10;
                double r = bas * 0.92, g = bas, b = bas * 0.95;
                int tx = x % tileW, ty = y % tileH;
                if (tx < 3 || ty < 3) { r *= 0.45; g *= 0.45; b *= 0.45; }
                else { double sh = (1.0 - tx / (double)tileW) * 0.10 + (1.0 - ty / (double)tileH) * 0.06; r += sh * 40; g += sh * 40; b += sh * 42; }
                if (y > 300 && y < 312) { r *= 0.5; g *= 0.5; b *= 0.48; }
                if (y > 470) { r *= 0.6; g *= 0.6; b *= 0.58; }
                Set(x, y, r, g, b, 255);
            }
        var rng = new Random(7);
        for (int s = 0; s < 14; s++)
        {
            int sx = rng.Next(0, 512), top = rng.Next(0, 200), len = rng.Next(120, 320), wdt = rng.Next(6, 22);
            for (int y = top; y < top + len && y < 512; y++)
            {
                double t = (y - top) / (double)len;
                for (int dx = -wdt; dx <= wdt; dx++)
                    Blend(sx + dx, y, 30, 26, 18, (1.0 - Math.Abs(dx) / (double)wdt) * t * 0.22);
            }
        }
        Save(path);
    }

    public static void Floor(string path)
    {
        NewCanvas(512, 512); InitPerm(23); int tile = 128;
        for (int y = 0; y < 512; y++)
            for (int x = 0; x < 512; x++)
            {
                double n = Fbm(x / 70.0, y / 70.0, 5, 2.0, 0.55);
                double grime = Fbm(x / 200.0, y / 200.0, 3, 2.0, 0.6);
                double bas = 60 + (n - 0.5) * 30 - grime * 22;
                double r = bas * 0.95, g = bas, b = bas * 1.02;
                int tx = x % tile, ty = y % tile;
                if (tx < 4 || ty < 4) { r *= 0.4; g *= 0.4; b *= 0.42; }
                double scuff = Fbm(x / 8.0, y / 40.0, 2, 2.0, 0.5);
                r += (scuff - 0.5) * 8; g += (scuff - 0.5) * 8; b += (scuff - 0.5) * 8;
                Set(x, y, r, g, b, 255);
            }
        Save(path);
    }

    public static void Ceiling(string path)
    {
        NewCanvas(512, 512); InitPerm(31); int tile = 128;
        for (int y = 0; y < 512; y++)
            for (int x = 0; x < 512; x++)
            {
                double speck = Fbm(x / 4.0, y / 4.0, 3, 2.3, 0.5);
                double stain = Fbm(x / 120.0, y / 120.0, 4, 2.0, 0.6);
                double bas = 52 + (speck - 0.5) * 22 - stain * 26;
                double r = bas * 1.05, g = bas * 0.98, b = bas * 0.82;
                int tx = x % tile, ty = y % tile;
                if (tx < 2 || ty < 2) { r *= 0.45; g *= 0.45; b *= 0.4; }
                Set(x, y, r, g, b, 255);
            }
        Save(path);
    }

    static void DoorBody(int S, double bR, double bG, double bB, int seed)
    {
        InitPerm(seed);
        int frame = (int)(S * 0.08);
        for (int y = 0; y < S; y++)
            for (int x = 0; x < S; x++)
            {
                double grain = Fbm(x / 8.0, y / 60.0, 4, 2.0, 0.55);
                double r = bR + (grain - 0.5) * 30, g = bG + (grain - 0.5) * 22, b = bB + (grain - 0.5) * 16;
                bool inX = (x > frame && x < S - frame);
                bool topP = inX && y > S * 0.10 && y < S * 0.45;
                bool botP = inX && y > S * 0.55 && y < S * 0.90;
                if (topP || botP) { r *= 0.82; g *= 0.82; b *= 0.82; }
                if (y > S * 0.46 && y < S * 0.54) { r *= 1.08; g *= 1.08; b *= 1.08; }
                Set(x, y, r, g, b, 255);
            }
        int[][] bevels = new int[][] { new int[]{(int)(S*0.10),(int)(S*0.45)}, new int[]{(int)(S*0.55),(int)(S*0.90)} };
        foreach (var bv in bevels)
        {
            int y0 = bv[0], y1 = bv[1];
            for (int y = y0; y < y1; y++)
            {
                Blend(frame, y, 0, 0, 0, 0.35);
                Blend(frame + 1, y, 0, 0, 0, 0.2);
                Blend(S - frame, y, 255, 255, 255, 0.12);
            }
            for (int x = frame; x < S - frame; x++) { Blend(x, y0, 0, 0, 0, 0.35); Blend(x, y1 - 1, 255, 255, 255, 0.12); }
        }
    }

    public static void Wood(string path)
    {
        NewCanvas(512, 512); InitPerm(43); int plank = 96;
        for (int y = 0; y < 512; y++)
            for (int x = 0; x < 512; x++)
            {
                int pi = y / plank;
                double tone = ValNoise(pi * 3.7, 0.5);
                double grain = Fbm(x / 6.0 + pi * 10, (y % plank) / 30.0, 4, 2.1, 0.55);
                double ring = Math.Sin(grain * 18 + x * 0.02) * 0.5 + 0.5;
                double bas = 70 + tone * 30 + (ring - 0.5) * 34;
                double r = bas, g = bas * 0.66, b = bas * 0.40;
                if (y % plank < 3) { r *= 0.35; g *= 0.3; b *= 0.28; }
                Set(x, y, r, g, b, 255);
            }
        Save(path);
    }

    public static void Metal(string path)
    {
        NewCanvas(512, 512); InitPerm(53); int panel = 168;
        for (int y = 0; y < 512; y++)
            for (int x = 0; x < 512; x++)
            {
                double brush = Fbm(x / 3.0, y / 60.0, 3, 2.0, 0.5);
                double macro = Fbm(x / 100.0, y / 100.0, 3, 2.0, 0.55);
                double bas = 96 + (brush - 0.5) * 26 + (macro - 0.5) * 30;
                double r = bas * 0.96, g = bas * 0.98, b = bas * 1.06;
                if (x % panel < 3) { r *= 0.5; g *= 0.5; b *= 0.55; }
                if (y % panel < 3) { r *= 0.5; g *= 0.5; b *= 0.55; }
                Set(x, y, r, g, b, 255);
            }
        var rng = new Random(99);
        for (int s = 0; s < 10; s++)
        {
            int cx = rng.Next(0, 512), cy = rng.Next(0, 512), rad = rng.Next(20, 70);
            for (int dy = -rad; dy <= rad; dy++)
                for (int dx = -rad; dx <= rad; dx++)
                {
                    double d = Math.Sqrt(dx * dx + dy * dy);
                    if (d > rad) continue;
                    double rn = Fbm((cx + dx) / 12.0, (cy + dy) / 12.0, 3, 2.0, 0.5);
                    Blend(cx + dx, cy + dy, 120, 62, 28, (1.0 - d / rad) * rn * 0.5);
                }
        }
        Save(path);
    }

    public static void Door(string path)
    {
        int S = 512; NewCanvas(S, S);
        DoorBody(S, 92, 60, 36, 61);
        int hx = (int)(S * 0.82), hy = (int)(S * 0.50);
        for (int dy = -10; dy <= 10; dy++)
            for (int dx = -18; dx <= 18; dx++)
            {
                double d = Math.Sqrt((dx / 1.8) * (dx / 1.8) + dy * dy);
                if (d <= 11) { double sh = 1.0 - dy / 14.0 - dx / 40.0; Set(hx + dx, hy + dy, 150 * sh, 130 * sh, 70 * sh, 255); }
            }
        Save(path);
    }

    public static void ExitDoor(string path)
    {
        int S = 512; NewCanvas(S, S);
        DoorBody(S, 96, 30, 26, 67);
        int by0 = (int)(S * 0.05), by1 = (int)(S * 0.16), bx0 = (int)(S * 0.22), bx1 = (int)(S * 0.78);
        for (int y = by0; y < by1; y++)
            for (int x = bx0; x < bx1; x++)
            {
                double glow = 1.0 - Math.Abs((y - (by0 + by1) / 2.0) / ((by1 - by0) / 2.0)) * 0.3;
                Set(x, y, 30 * glow, 180 * glow, 80 * glow, 255);
            }
        string[] E = { "111", "100", "110", "100", "111" };
        string[] X = { "101", "101", "010", "101", "101" };
        string[] I = { "111", "010", "010", "010", "111" };
        string[] T = { "111", "010", "010", "010", "010" };
        string[][] word = { E, X, I, T };
        int cell = (bx1 - bx0) / (4 * 4);
        int lx = bx0 + cell, ly = by0 + (int)((by1 - by0) * 0.18);
        foreach (var gl in word)
        {
            for (int ry = 0; ry < 5; ry++)
                for (int rx = 0; rx < 3; rx++)
                    if (gl[ry][rx] == '1')
                        for (int py = 0; py < cell; py++)
                            for (int px = 0; px < cell; px++)
                                Set(lx + rx * cell + px, ly + ry * cell + py, 235, 245, 235, 255);
            lx += 4 * cell;
        }
        int py0 = (int)(S * 0.58), py1 = (int)(S * 0.64);
        for (int y = py0; y < py1; y++)
            for (int x = (int)(S * 0.12); x < (int)(S * 0.88); x++)
            {
                double sh = 1.0 - (y - py0) / (double)(py1 - py0) * 0.5;
                Set(x, y, 150 * sh, 148 * sh, 135 * sh, 255);
            }
        Save(path);
    }

    public static void Fuse(string path)
    {
        int S = 256; NewCanvas(S, S); InitPerm(71);
        RectF(72, 96, 184, 160, 210, 220, 230, 0.85);
        for (int x = 72; x <= 184; x++)
        {
            double sh = Math.Sin((x - 72) / 112.0 * 3.14159) * 0.4 + 0.6;
            RectF(x, 96, x, 160, 200 * sh + 40, 210 * sh + 40, 225 * sh + 40, 0.5);
        }
        RectF(56, 92, 80, 164, 175, 178, 185, 1.0);
        RectF(176, 92, 200, 164, 175, 178, 185, 1.0);
        RectF(56, 92, 80, 100, 215, 218, 225, 0.6);
        RectF(176, 92, 200, 100, 215, 218, 225, 0.6);
        for (int x = 82; x <= 174; x++) Set(x, 128 + (int)(Math.Sin(x * 0.5) * 8), 60, 50, 40, 255);
        Save(path);
    }

    public static void Key(string path)
    {
        int S = 256; NewCanvas(S, S); InitPerm(73);
        double br = 175, bg = 140, bb = 55;
        Disc(170, 100, 46, 46, br, bg, bb, 1.0);
        for (int y = 78; y <= 122; y++) for (int x = 148; x <= 192; x++)
            if ((x - 170) * (x - 170) + (y - 100) * (y - 100) < 484) Clear(x, y);
        RectF(60, 92, 150, 110, br, bg, bb, 1.0);
        RectF(60, 110, 78, 140, br, bg, bb, 1.0);
        RectF(88, 110, 104, 134, br, bg, bb, 1.0);
        for (int y = 60; y < 150; y++) for (int x = 50; x < 220; x++)
        {
            int i = (y * S + x) * 4;
            if (buf[i + 3] > 0) Blend(x, y, 90, 55, 20, Fbm(x / 18.0, y / 18.0, 3, 2.0, 0.5) * 0.35);
        }
        Save(path);
    }

    public static void Herb(string path)
    {
        int S = 256; NewCanvas(S, S); InitPerm(79);
        double[][] leaves = {
            new double[]{128,100,34,60}, new double[]{96,150,30,56}, new double[]{160,150,30,56},
            new double[]{112,130,26,48}, new double[]{144,130,26,48}
        };
        foreach (var lf in leaves)
        {
            double lx = lf[0], ly = lf[1], rx = lf[2], ry = lf[3];
            for (int y = (int)(ly - ry); y <= (int)(ly + ry); y++)
                for (int x = (int)(lx - rx); x <= (int)(lx + rx); x++)
                {
                    double dx = (x - lx) / rx, dy = (y - ly) / ry;
                    if (dx * dx + dy * dy <= 1.0)
                    {
                        double n = Fbm(x / 20.0, y / 20.0, 3, 2.0, 0.5);
                        double g = 110 + n * 60 - ly * 0.1;
                        if (Math.Abs(dx) < 0.08) g *= 0.7;
                        Blend(x, y, 30 + n * 30, g, 34 + n * 20, 1.0);
                    }
                }
        }
        Save(path);
    }

    public static void Ammo(string path)
    {
        int S = 256; NewCanvas(S, S); InitPerm(83);
        for (int y = 90; y <= 180; y++) for (int x = 40; x <= 216; x++)
        {
            double n = Fbm(x / 30.0, y / 30.0, 3, 2.0, 0.5), sh = 1.0 - (y - 90) / 180.0;
            Set(x, y, (90 + n * 30) * sh + 20, (70 + n * 25) * sh + 15, (48 + n * 20) * sh + 10, 255);
        }
        RectF(40, 110, 216, 114, 40, 30, 22, 0.8);
        for (int m = 0; m < 5; m++)
        {
            int mx = 60 + m * 34;
            RectF(mx, 60, mx + 22, 100, 200, 168, 60, 1.0);
            RectF(mx, 60, mx + 22, 70, 225, 200, 110, 1.0);
            Disc(mx + 11, 60, 11, 8, 215, 188, 95, 1.0);
        }
        Save(path);
    }

    public static void Note(string path)
    {
        int S = 256; NewCanvas(S, S); InitPerm(89);
        for (int y = 20; y <= 236; y++) for (int x = 36; x <= 220; x++)
        {
            double n = Fbm(x / 40.0, y / 40.0, 4, 2.0, 0.55);
            double edge = Math.Min(Math.Min(x - 36, y - 20), Math.Min(220 - x, 236 - y)) / 30.0;
            if (edge > 1) edge = 1;
            Set(x, y, (200 + n * 30) * (0.7 + edge * 0.3), (188 + n * 28) * (0.68 + edge * 0.3), (150 + n * 24) * (0.6 + edge * 0.3), 255);
        }
        var rng = new Random(5);
        for (int ln = 0; ln < 9; ln++)
        {
            int y = 48 + ln * 20, x = 52;
            while (x < 200) { int w = rng.Next(8, 26); RectF(x, y, x + w, y + 2, 70, 62, 50, 0.7); x += w + rng.Next(4, 12); }
        }
        Save(path);
    }

    public static void Debris(string path)
    {
        int S = 256; NewCanvas(S, S); InitPerm(97);
        for (int y = 0; y < S; y++) for (int x = 0; x < S; x++)
        {
            double n = Fbm(x / 40.0, y / 40.0, 5, 2.1, 0.55), fine = Fbm(x / 6.0, y / 6.0, 3, 2.0, 0.5);
            double bas = 40 + n * 30 + (fine - 0.5) * 16;
            Set(x, y, bas, bas * 0.92, bas * 0.82, 255);
        }
        var rng = new Random(3);
        for (int s = 0; s < 18; s++)
        {
            int px = rng.Next(10, S - 30), py = rng.Next(10, S - 30), sz = rng.Next(10, 34), tone = rng.Next(-20, 30);
            for (int dy = 0; dy < sz; dy++) for (int dx = 0; dx < sz - dy; dx++)
                Blend(px + dx, py + dy, 70 + tone, 66 + tone, 58 + tone, 0.5);
        }
        Save(path);
    }

    public static void Blood(string path)
    {
        int S = 256; NewCanvas(S, S); InitPerm(101);
        int cx = 128, cy = 128;
        for (int y = 0; y < S; y++) for (int x = 0; x < S; x++)
        {
            double dx = x - cx, dy = y - cy, d = Math.Sqrt(dx * dx + dy * dy);
            double rad = 70 + Fbm(x / 30.0, y / 30.0, 4, 2.0, 0.55) * 40;
            if (d < rad)
            {
                double dark = 0.55 + Fbm(x / 15.0, y / 15.0, 3, 2.0, 0.5) * 0.45;
                Blend(x, y, 90 * dark + 20, 10 * dark, 8 * dark, Math.Min(1.0, (1.0 - d / rad) * 6.0));
            }
        }
        var rng = new Random(13);
        for (int s = 0; s < 40; s++)
        {
            double ang = rng.NextDouble() * 6.283; int dist = 60 + rng.Next(0, 60);
            int sx = cx + (int)(Math.Cos(ang) * dist), sy = cy + (int)(Math.Sin(ang) * dist), sz = rng.Next(2, 8);
            Disc(sx, sy, sz, sz, 80, 9, 7, 0.85);
        }
        Save(path);
    }
}
'@

Add-Type -TypeDefinition $src -ReferencedAssemblies "System.Drawing"

[TexGen]::Wall((Join-Path $hospital "wall.png")); Write-Host "  wall.png"
[TexGen]::Floor((Join-Path $hospital "floor.png")); Write-Host "  floor.png"
[TexGen]::Ceiling((Join-Path $hospital "ceiling.png")); Write-Host "  ceiling.png"
[TexGen]::Wood((Join-Path $hospital "wood.png")); Write-Host "  wood.png"
[TexGen]::Metal((Join-Path $hospital "metal.png")); Write-Host "  metal.png"
[TexGen]::Door((Join-Path $hospital "door.png")); Write-Host "  door.png"
[TexGen]::ExitDoor((Join-Path $hospital "exit_door.png")); Write-Host "  exit_door.png"
[TexGen]::Fuse((Join-Path $props "fuse.png")); Write-Host "  fuse.png"
[TexGen]::Key((Join-Path $props "key.png")); Write-Host "  key.png"
[TexGen]::Herb((Join-Path $props "herb.png")); Write-Host "  herb.png"
[TexGen]::Ammo((Join-Path $props "ammo.png")); Write-Host "  ammo.png"
[TexGen]::Note((Join-Path $props "note.png")); Write-Host "  note.png"
[TexGen]::Debris((Join-Path $props "debris.png")); Write-Host "  debris.png"
[TexGen]::Blood((Join-Path $props "blood.png")); Write-Host "  blood.png"

Write-Host ""
Write-Host "Realistik texture'lar uretildi (pistol/knife haric)."
Get-ChildItem $hospital, $props -Filter "*.png" | Format-Table Name, Length
