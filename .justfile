set shell := ["pwsh", "-NoLogo", "-Command"]

dist:
	Ahk2Exe /in "ScreenOCR.ahk" /icon "assets/icon.ico" /out "ScreenOCR.exe"

clean:
	rm ScreenOCR.exe
