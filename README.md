<div align="center">
  <img src="assets/icon.png" alt="icon" width="32" />
</div>

# AHK-ScreenOCR

Screen OCR with [Tesseract](https://github.com/tesseract-ocr/tesseract) and [RapidOCR](https://github.com/RapidAI/RapidOCR) (PaddleOCR ONNX, PP-OCRv5). Edit `ScreenOCR.ini` to configure.

Authors: GLM-5.1🧙‍♂️, scillidan🤡

The icon is from [SimpleKeys](https://beamedeighth.itch.io/simplekeys-animated-pixel-keyboard-keys) by [beamedeighth](https://beamedeighth.itch.io/).

## Requirements

- [AutoHotkey v1](https://www.autohotkey.com)
- [uv](https://docs.astral.sh/uv/)
- [tesseract](https://github.com/tesseract-ocr/tesseract)
- [leptonica_util](https://github.com/tesseract-ocr/tesseract) (Tesseract dependency)
- [snoretoast](https://github.com/KDE/snoretoast) (Optional)
- [flameshot](https://github.com/flameshot-org/flameshot) (Optional)

## Usage

1. Pre-install RapidOCR: `uv run lib\rapidocr_cli.py --list-langs`
2. Test: `uv run lib\rapidocr_cli.py cache\testit.jpg cache\testit.txt ch`
3. Run `autohotkeyu6 ScreenOCR.ahk`
4. Trigger OCR via hotkey, select screen area, text is copied to clipboard

## Third-party Libraries

|Library|Author|License|Source|
|:-|:-|:-|:-|
|OCR.ahk (fork of Vis2.ahk)|Edison Hua (iseahound)|Custom|https://github.com/iseahound/Vis2|
|ImagePut.ahk|Edison Hua (iseahound)|MIT|https://github.com/iseahound/ImagePut|
|Gdip_All.ahk|tic (Tariq Porter), mod. Rseding91|Unspecified|https://github.com/tariqporter/Gdip|
