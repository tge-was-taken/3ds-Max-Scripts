for %%f in (Convert/*.gtx) do texconv2 -i Convert/%%f -o OutDDS/%%~nf.dds
for %%f in (Convert/*.gtx) do texconv2 -i Convert/%%f -f GX2_SURFACE_FORMAT_TCS_R8_G8_B8_A8_UNORM  -o OutDDS_Lossless/%%~nf.gtx
for %%f in (OutDDS_Lossless/*.gtx) do texconv2 -i OutDDS_Lossless/%%f -o OutDDS_Lossless/%%~nf.dds

cd OutDDS_Lossless
del *.gtx
cd..
