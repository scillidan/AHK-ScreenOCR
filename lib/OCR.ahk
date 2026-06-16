; Script:    Vis2.ahk
; License:   Custom
; Author:    Edison Hua (iseahound)
; Date:      2022-03-03
; Version:   2.1.0

#include %A_LineFile%\..\Gdip_All.ahk
#include %A_LineFile%\..\ImagePut.ahk


OCR(image:="", language:="", options:=""){
   return Vis2.OCR(image, language, options)
}

class Vis2 {

    class OCR extends Vis2.functor {
       call(self, image:="", language:="", options:=""){
          provider := this._pickProvider(language)
          Vis2.cfg.usedEngine := Vis2.cfg.currentEngine
          Vis2.cfg.usedLang := Vis2.cfg.currentLang
          return (image != "") ? (new provider()).OCR(image, language, options)
             : Vis2.core.returnText({"provider":(new provider(language))})
       }

      _pickProvider(language:=""){
         if (!IsObject(Vis2.cfg))
            return Vis2.provider.Tesseract
         engine := Vis2.cfg.currentEngine
         if (engine = "rapidocr")
            return Vis2.provider.RapidOCR
         return Vis2.provider.Tesseract
      }
   }

   class core {

      ; returnText() is a wrapper function of Vis2.core.ux.start()
      ; Unlike Vis2.core.ux.start(), this function will return a string of text.
      returnText(obj := ""){
         obj := IsObject(obj) ? obj : {}
         obj.callback := "returnText"
         if (Vis2.core.ux.start(obj) == "") {
            while !(EXITCODE := Vis2.obj.EXITCODE)
               Sleep 1
            text := Vis2.obj.database
            Vis2.obj.callbackConfirmed := true
            text.base.google := ObjBindMethod(Vis2.Text, "google")
            text.base.clipboard := ObjBindMethod(Vis2.Text, "clipboard")
            return (EXITCODE > 0) ? text : ""
         }
      }

      class ux {

          start(obj := ""){
          static void := ObjBindMethod({}, {})

             if (Vis2.obj != "")
                return "Already in use."

             Vis2.Graphics.Startup()
             Vis2.stdlib.setSystemCursor(32515)
             Hotkey, LButton, % void, On
             Hotkey, RButton, % void, On
             Hotkey, Escape, % void, On

             Vis2.obj := IsObject(obj) ? obj : {}
             Vis2.obj.EXITCODE := 0
             Vis2.obj.area := new Vis2.Graphics.Area("Vis2_Aries", "0x7FDDDDDD")

             Vis2.core.ux.waitForUserInput()
          }

          waitForUserInput(){
          static escape := ObjBindMethod(Vis2.core.ux, "escape")
          static waitForUserInput := ObjBindMethod(Vis2.core.ux, "waitForUserInput")
          static drawSelection := ObjBindMethod(Vis2.core.ux, "drawSelection")

             if (GetKeyState("Escape", "P") || GetKeyState("RButton", "P")) {
                Vis2.obj.EXITCODE := -1
                SetTimer, % escape, -9
                return
             }
             if (GetKeyState("LButton", "P")) {
                Vis2.obj.area.origin()
                SetTimer, % drawSelection, -10
             }
             else {
                Vis2.obj.area.origin()
                SetTimer, % waitForUserInput, -10
             }
          }

          drawSelection(){
          static drawSelection := ObjBindMethod(Vis2.core.ux, "drawSelection")
          static escape := ObjBindMethod(Vis2.core.ux, "escape")

             if (GetKeyState("Escape", "P") || GetKeyState("RButton", "P")) {
                Vis2.obj.EXITCODE := -1
                SetTimer, % escape, -9
                return
             }
             if (GetKeyState("LButton", "P")) {
                Vis2.obj.area.draw()
                SetTimer, % drawSelection, -10
             }
             else {
                Vis2.core.ux.doOCR()
             }
          }

          doOCR(){
          static void := ObjBindMethod({}, {})
          static cleanup := ObjBindMethod(Vis2.core.ux, "cleanup")

              Hotkey, LButton, % void, Off
              Hotkey, RButton, % void, Off
              Hotkey, Escape, % void, Off
              DllCall("SystemParametersInfo", "uInt",0x57, "uInt",0, "uInt",0, "uInt",0)

              try {
                 coordinates := Vis2.obj.area.ScreenshotRectangle()
                 if (coordinates) {
                    pBitmap := ImagePutBitmap({screenshot: coordinates})
                    ImagePutFile({bitmap: pBitmap}, Vis2.obj.provider.file, Vis2.obj.provider.jpegQuality)
                    Gdip_DisposeImage(pBitmap)
                 }
              } catch e {
                 Vis2.obj.EXITCODE := -1
                 Vis2.obj.area.destroy()
                 SetTimer, % cleanup, -9
                 return
              }
              Vis2.obj.area.destroy()

               if (Vis2.cfg.recogMsg)
                  TrayTip, AHK-ScreenOCR, % Vis2.cfg.recogMsg, 3
               try {
                  if (coordinates) {
                     Vis2.obj.provider.preprocess()
                     Vis2.obj.provider.convert()
                     Vis2.obj.database := Vis2.obj.provider.getText()
                  }
               } catch e {
                  ShowNotification("AHK-ScreenOCR Error", e.message)
                  Vis2.obj.EXITCODE := -1
               }

                if (Vis2.obj.database = "" && Vis2.obj.EXITCODE == 0 && Vis2.cfg.mode = "global" && coordinates) {
                    fallbackEngine := ""
                    if (Vis2.cfg.currentEngine = "tesseract" && Vis2.cfg.rapidEnabled)
                        fallbackEngine := "rapidocr"
                    else if (Vis2.cfg.currentEngine = "rapidocr" && Vis2.cfg.tessEnabled)
                        fallbackEngine := "tesseract"
                    if (fallbackEngine != "") {
                        fallbackLang := (fallbackEngine = "tesseract") ? Vis2.cfg.tessLang : Vis2.cfg.rapidLang
                        fallbackClass := (fallbackEngine = "tesseract") ? Vis2.provider.Tesseract : Vis2.provider.RapidOCR
                        fallbackProv := new fallbackClass(fallbackLang)
                        try {
                            pBitmap := Gdip_CreateBitmapFromFile(Vis2.obj.provider.file)
                            ImagePutFile({bitmap: pBitmap}, fallbackProv.file, fallbackProv.jpegQuality)
                            Gdip_DisposeImage(pBitmap)
                            fallbackProv.preprocess()
                            fallbackProv.convert()
                            Vis2.obj.database := fallbackProv.getText()
                            Vis2.cfg.usedEngine := fallbackEngine
                            Vis2.cfg.usedLang := fallbackLang
                        } catch e2 {
                        }
                        fallbackProv.cleanup()
                    }
                }

               if (Vis2.obj.database != "" && Vis2.obj.EXITCODE == 0) {
                  if (Vis2.obj.noCopy != true) {
                     clipboard := Vis2.obj.database
                     if (Vis2.cfg.notify) {
                        text := Vis2.obj.database
                        if (StrLen(text) > 200)
                           text := SubStr(text, 1, 200) . "..."
                         prefix := ""
                         if (Vis2.cfg.mode = "global")
                            prefix := "[" . Vis2.cfg.usedEngine . " - " . Vis2.cfg.usedLang . "] "
                         else
                            prefix := "[" . Vis2.cfg.usedLang . "] "
                         ShowNotification("AHK-ScreenOCR", prefix . text)
                     }
                  }
                  Vis2.obj.EXITCODE := 1
               } else if (Vis2.obj.database == "" && Vis2.obj.EXITCODE == 0) {
                 if (Vis2.cfg.noTextMsg)
                    TrayTip, AHK-ScreenOCR, % Vis2.cfg.noTextMsg, 2
                 Vis2.obj.EXITCODE := -1
              } else if (Vis2.obj.EXITCODE == 0) {
                 Vis2.obj.EXITCODE := -1
              }
              SetTimer, % cleanup, -9
           }

           escape(){
           static void := ObjBindMethod({}, {})
           static cleanup := ObjBindMethod(Vis2.core.ux, "cleanup")

              Hotkey, LButton, % void, Off
              Hotkey, RButton, % void, Off
              Hotkey, Escape, % void, Off
              DllCall("SystemParametersInfo", "uInt",0x57, "uInt",0, "uInt",0, "uInt",0)
              TrayTip
              Vis2.obj.area.destroy()
              SetTimer, % cleanup, -9
           }

          cleanup(){
          static cleanup := ObjBindMethod(Vis2.core.ux, "cleanup")

             if (Vis2.obj.callback) {
                if !(Vis2.obj.callbackConfirmed) {
                   SetTimer, % cleanup, -9
                   return
                }
             }

             Vis2.obj.provider.cleanup()
             Vis2.obj := ""
             Vis2.Graphics.Shutdown()
          }
       }
   }

   class functor {

      __Call(method, ByRef arg := "", args*) {
      ; When casting to Call(), use a new instance of the "function object"
      ; so as to avoid directly storing the properties(used across sub-methods)
      ; into the "function object" itself.
      ; Thanks to coco for this code. Modified by iseahound.
         if IsObject(method)
            return (new this).Call(method, arg, args*)
         else if (method == "")
            return (new this).Call(arg, args*)
      }
   }

   class Graphics {

      static pToken, Gdip := 0

      Startup(){
         global pToken
         return Vis2.Graphics.pToken := (Vis2.Graphics.Gdip++ > 0) ? Vis2.Graphics.pToken : (pToken) ? pToken : Gdip_Startup()
      }

      Shutdown(){
         global pToken
         return Vis2.Graphics.pToken := (--Vis2.Graphics.Gdip <= 0) ? ((pToken) ? pToken : Gdip_Shutdown(Vis2.Graphics.pToken)) : Vis2.Graphics.pToken
      }

      Name(){
         VarSetCapacity(UUID, 16, 0)
         if (DllCall("rpcrt4.dll\UuidCreate", "ptr", &UUID) != 0)
             return (ErrorLevel := 1) & 0
         if (DllCall("rpcrt4.dll\UuidToString", "ptr", &UUID, "uint*", suuid) != 0)
             return (ErrorLevel := 2) & 0
         return A_TickCount "n" SubStr(StrGet(suuid), 1, 8), DllCall("rpcrt4.dll\RpcStringFree", "uint*", suuid)
      }

      class Area{

         ScreenWidth := A_ScreenWidth, ScreenHeight := A_ScreenHeight,
         action := ["base"], x := [0], y := [0], w := [1], h := [1], a := ["top left"], q := ["bottom right"]

         __New(name := "", color := "0x7FDDDDDD") {
            this.name := name := (name == "") ? Vis2.Graphics.Name() "_Graphics_Area" : name "_Graphics_Area"
            this.color := color

            Vis2.Graphics.Startup()
            Gui, %name%:New, +LastFound +AlwaysOnTop -Caption -DPIScale +E0x80000 +ToolWindow +hwndSecretName, % this.name
            Gui, %name%:Show, % (this.isDrawable()) ? "NoActivate" : ""
            this.hwnd := SecretName
            this.hbm := CreateDIBSection(this.ScreenWidth, this.ScreenHeight)
            this.hdc := CreateCompatibleDC()
            this.obm := SelectObject(this.hdc, this.hbm)
            this.G := Gdip_GraphicsFromHDC(this.hdc)
            Gdip_SetSmoothingMode(this.G, 4) ;Adds one clickable pixel to the edge.
            this.pBrush := Gdip_BrushCreateSolid(this.color)
         }

         __Delete(){
            Vis2.Graphics.Shutdown()
         }

         Destroy(){
            Gdip_DeleteBrush(this.pBrush)
            SelectObject(this.hdc, this.obm)
            DeleteObject(this.hbm)
            DeleteDC(this.hdc)
            Gdip_DeleteGraphics(this.G)
            Gui, % this.name ":Destroy"
         }

         Hide(){
            DllCall("ShowWindow", "ptr",this.hWnd, "int",0)
         }

         Show(){ ; NoActivate
            DllCall("ShowWindow", "ptr",this.hWnd, "int",8)
         }

         ToggleVisible(){
            this.isVisible() ? this.Hide() : this.Show()
         }

         isVisible(){
            return DllCall("IsWindowVisible", "ptr",this.hWnd)
         }

         isDrawable(win := "A"){
             static WM_KEYDOWN := 0x100,
             static WM_KEYUP := 0x101,
             static vk_to_use := 7
             ; Test whether we can send keystrokes to this window.
             ; Use a virtual keycode which is unlikely to do anything:
             PostMessage, WM_KEYDOWN, vk_to_use, 0,, % win
             if !ErrorLevel
             {   ; Seems best to post key-up, in case the window is keeping track.
                 PostMessage, WM_KEYUP, vk_to_use, 0xC0000000,, % win
                 return true
             }
             return false
         }

         DetectScreenResolutionChange(){
            if (this.ScreenWidth != A_ScreenWidth || this.ScreenHeight != A_ScreenHeight) {
               this.ScreenWidth := A_ScreenWidth, this.ScreenHeight := A_ScreenHeight
               SelectObject(this.hdc, this.obm)
               DeleteObject(this.hbm)
               DeleteDC(this.hdc)
               Gdip_DeleteGraphics(this.G)
               this.hbm := CreateDIBSection(this.ScreenWidth, this.ScreenHeight)
               this.hdc := CreateCompatibleDC()
               this.obm := SelectObject(this.hdc, this.hbm)
               this.G := Gdip_GraphicsFromHDC(this.hdc)
               Gdip_SetSmoothingMode(this.G, 4)
            }
         }

          Redraw(x, y, w, h){
             Critical On
             this.DetectScreenResolutionChange()
             Gdip_GraphicsClear(this.G)
             Gdip_FillRectangle(this.G, this.pBrush, x, y, w, h)
             UpdateLayeredWindow(this.hwnd, this.hdc, 0, 0, this.ScreenWidth, this.ScreenHeight)
             Critical Off
          }

          Propagate(v){
             this.a[v] := (this.a[v] == "") ? this.a[v-1] : this.a[v]
             this.q[v] := (this.q[v] == "") ? this.q[v-1] : this.q[v]
             this.x[v] := (this.x[v] == "") ? this.x[v-1] : this.x[v]
             this.y[v] := (this.y[v] == "") ? this.y[v-1] : this.y[v]
             this.w[v] := (this.w[v] == "") ? this.w[v-1] : this.w[v]
             this.h[v] := (this.h[v] == "") ? this.h[v-1] : this.h[v]
          }

         Origin(v := ""){
            CoordMode, Mouse, Screen
            MouseGetPos, x_mouse, y_mouse

            if (A_ThisFunc != this.action[this.action.MaxIndex()]){
               this.action.push(A_ThisFunc)
               this.x_hover := x_mouse
               this.y_hover := y_mouse
            }

            v := (v) ? v : this.action.MaxIndex()

            if (x_mouse != this.x_last || y_mouse != this.y_last) {
               this.x_last := x_mouse, this.y_last := y_mouse

               this.x[v] := x_mouse
               this.y[v] := y_mouse

               this.Propagate(v)
               this.Redraw(x_mouse, y_mouse, 1, 1) ;stabilize x/y corrdinates in window spy.
            }
         }

         Draw(v := ""){
            CoordMode, Mouse, Screen
            MouseGetPos, x_mouse, y_mouse

            if (A_ThisFunc == this.action[this.action.MaxIndex()-1]){
               this.BackPropagate(this.action.MaxIndex())
               this.x_hover := x_mouse
               this.y_hover := y_mouse
               pass := 1
            }
            if (A_ThisFunc != this.action[this.action.MaxIndex()]){
               this.Converge()
               this.action.push(A_ThisFunc)
               this.x_hover := x_mouse
               this.y_hover := y_mouse
               pass := 1
            }

            v := (v) ? v : this.action.MaxIndex()
            dx := x_mouse - this.x_hover
            dy := y_mouse - this.y_hover
            xr := (x_mouse > this.x[v-1]) ? 1 : 0
            yr := (y_mouse > this.y[v-1]) ? 1 : 0

            if (pass == 1 || x_mouse != this.x_last || y_mouse != this.y_last) {
               this.x_last := x_mouse, this.y_last := y_mouse

               this.x[v] := (xr) ? this.x[v-1] : x_mouse
               this.y[v] := (yr) ? this.y[v-1] : y_mouse
               this.w[v] := (xr) ? x_mouse - this.x[v-1] : this.x[v-1] - x_mouse
               this.h[v] := (yr) ? y_mouse - this.y[v-1] : this.y[v-1] - y_mouse

               this.a[v] := (xr && yr) ? "top left" : (xr && !yr) ? "bottom left" : (!xr && yr) ? "top right" : "bottom right"
               this.q[v] := (xr && yr) ? "bottom right" : (xr && !yr) ? "top right" : (!xr && yr) ? "bottom left" : "top left"

               this.Propagate(v)
               this.Redraw(this.x[v], this.y[v], this.w[v], this.h[v])
             }
          }

          ScreenshotRectangle(){
            x := this.x1(), y := this.y1(), w := this.width(), h := this.height()
            return (w > 0 && h > 0) ? [x, y, w, h] : ""
         }

         x1(){
            return this.x[this.x.MaxIndex()]
         }

         x2(){
            return this.x[this.x.MaxIndex()] + this.w[this.w.MaxIndex()]
         }

         y1(){
            return this.y[this.y.MaxIndex()]
         }

         y2(){
            return this.y[this.y.MaxIndex()] + this.h[this.h.MaxIndex()]
         }

         width(){
            return this.w[this.w.MaxIndex()]
         }

         height(){
            return this.h[this.h.MaxIndex()]
         }
       }
     }

    class provider {

        class Tesseract {
           static slowProvider := false
           static leptonica := "leptonica_util"
           static tesseract := "tesseract"
           static tessdata := ""

           uuid := Vis2.stdlib.CreateUUID()
           file := A_Temp "\Vis2_screenshot" this.uuid ".bmp"
           fileProcessedImage := A_Temp "\Vis2_preprocess" this.uuid ".tif"
           fileConvertedText := A_Temp "\Vis2_text" this.uuid ".txt"

           __New(language:=""){
              this.language := language
              if (IsObject(Vis2.cfg) && Vis2.cfg.tessdata != "") {
                 Vis2.provider.Tesseract.tessdata := Vis2.cfg.tessdata
              } else {
                 EnvGet, tessPrefix, TESSDATA_PREFIX
                 if (tessPrefix != "")
                    Vis2.provider.Tesseract.tessdata := tessPrefix
              }
           }

           OCR(image, language:="", options:=""){
              this.language := language
              try {
                 screenshot := ImagePutFile({image: image, crop: options}, this.file)
                 this.preprocess(screenshot, this.fileProcessedImage)
                 this.convert_best(this.fileProcessedImage, this.fileConvertedText)
                 text := this.getText(this.fileConvertedText)
              } catch e {
                 MsgBox, 16,, % "Exception thrown!`n`nwhat: " e.what "`nfile: " e.file
                    . "`nline: " e.line "`nmessage: " e.message "`nextra: " e.extra
              }
              finally {
                 this.cleanup()
                 text.base.google := ObjBindMethod(Vis2.Text, "google")
                 text.base.clipboard := ObjBindMethod(Vis2.Text, "clipboard")
              }
              return text
           }

           cleanup(){
              FileDelete, % this.file
              FileDelete, % this.fileProcessedImage
              FileDelete, % this.fileConvertedText
           }

           convert(in:="", out:=""){
              in := (in) ? in : this.fileProcessedImage
              out := (out) ? out : this.fileConvertedText

              if !(FileExist(in))
                 throw Exception("Input image for conversion not found.",, in)

              static q := Chr(0x22)
              _cmd .= q this.tesseract q
              if (this.tessdata != "")
                 _cmd .= " --tessdata-dir " q this.tessdata q
              _cmd .= " " q in q " " q SubStr(out, 1, -4) q
              _cmd .= (this.language) ? " -l " q this.language q : ""
              _cmd := ComSpec " /C " q _cmd q
              RunWait % _cmd,, Hide

              if !(FileExist(out))
                 throw Exception("Tesseract failed.",, _cmd)

              return out
           }

           convert_best(in:="", out:=""){
              return this.convert(in, out)
           }

           convert_fast(in:="", out:=""){
              return this.convert(in, out)
           }

           getPreprocessImage(){
              return this.fileProcessedImage
           }

           getText(in:="", lines:=""){
              in := (in) ? in : this.fileConvertedText

              if !(database := FileOpen(in, "r`n", "UTF-8"))
                 throw Exception("Text file could not be found or opened.",, in)

              if (lines == "") {
                 text := RegExReplace(database.Read(), "^\s*(.*?)\s*$", "$1")
                 text := RegExReplace(text, "(?<!\r)\n", "`r`n")
              } else {
                 while (lines > 0) {
                    data := database.ReadLine()
                    data := RegExReplace(data, "^\s*(.*?)\s*$", "$1")
                    if (data != "") {
                       text .= (text) ? ("`n" . data) : data
                       lines--
                    }
                    if (!database || database.AtEOF)
                       break
                 }
              }
              database.Close()
              return text
           }

           getTextLines(lines){
              return this.read(, lines)
           }

           preprocess(in:="", out:=""){
              static ocrPreProcessing := 1
              static negateArg := 2
              static performScaleArg := 1
              static scaleFactor := 3.5

              in := (in != "") ? in : this.file
              out := (out != "") ? out : this.fileProcessedImage

              if !(FileExist(in))
                 throw Exception("Input image for preprocessing not found.",, in)

              static q := Chr(0x22)
              _cmd .= q this.leptonica q " " q in q " " q out q
              _cmd .= " " negateArg " 0.5 " performScaleArg " " scaleFactor " " ocrPreProcessing " 5 2.5 " ocrPreProcessing  " 2000 2000 0 0 0.0"
              _cmd := ComSpec " /C " q _cmd q
              RunWait, % _cmd,, Hide

              if !(FileExist(out))
                 throw Exception("Preprocessing failed.",, _cmd)

              return out
           }
        }

       class RapidOCR {
          static slowProvider := true
          static useAngleCls := 1
          static python := "uv run"
          static script := "lib\rapidocr_cli.py"

          uuid := Vis2.stdlib.CreateUUID()
          file := A_Temp "\Vis2_screenshot" this.uuid ".png"
          fileProcessedImage := A_Temp "\Vis2_preprocess" this.uuid ".png"
          fileConvertedText := A_Temp "\Vis2_text" this.uuid ".txt"

          __New(language:=""){
             this.language := language
          }

          OCR(image, language:="", options:=""){
             this.language := language ? language : "ch"
             try {
                screenshot := ImagePutFile({image: image, crop: options}, this.file)
                this.preprocess(screenshot, this.fileProcessedImage)
                this.convert(this.fileProcessedImage, this.fileConvertedText)
                text := this.getText(this.fileConvertedText)
             } catch e {
                MsgBox, 16,, % "Exception thrown!`n`nwhat: " e.what "`nfile: " e.file
                   . "`nline: " e.line "`nmessage: " e.message "`nextra: " e.extra
             }
             finally {
                this.cleanup()
                text.base.google := ObjBindMethod(Vis2.Text, "google")
                text.base.clipboard := ObjBindMethod(Vis2.Text, "clipboard")
             }
             return text
          }

          preprocess(in:="", out:=""){
             in := (in != "") ? in : this.file
             out := (out != "") ? out : this.fileProcessedImage
             FileCopy, % in, % out, 1
             return out
          }

          getPreprocessImage(){
             return this.fileProcessedImage
          }

          convert(in:="", out:=""){
             in := (in) ? in : this.fileProcessedImage
             out := (out) ? out : this.fileConvertedText

             if !(FileExist(in))
                throw Exception("Input image for conversion not found.",, in)

             static q := Chr(0x22)
             lang := this.language ? this.language : "ch"
             _cmd := this.python " " q this.script q " " q in q " " q out q " " lang
             if (this.useAngleCls)
                _cmd .= " --use-angle-cls"
             _cmd := ComSpec " /C " q _cmd q
             Run % _cmd,, Hide, ocrPid
             loop {
                if FileExist(out)
                   break
                Process, Exist, %ocrPid%
                if !ErrorLevel
                   break
                Sleep 50
             }

             if !(FileExist(out))
                throw Exception("RapidOCR failed.",, _cmd)

             return out
          }

          getText(in:=""){
             in := (in) ? in : this.fileConvertedText

             if !(database := FileOpen(in, "r`n", "UTF-8"))
                throw Exception("Text file could not be found or opened.",, in)

             text := RegExReplace(database.Read(), "^\s*(.*?)\s*$", "$1")
             text := RegExReplace(text, "(?<!\r)\n", "`r`n")
             database.Close()
             return text
          }

          cleanup(){
             FileDelete, % this.file
             FileDelete, % this.fileProcessedImage
             FileDelete, % this.fileConvertedText
         }
      }
   }

   class stdlib {

      isBinaryImageFormat(data){
         Loop 12
            bytes .= Chr(NumGet(data, A_Index-1, "uchar"))

         ; Null bytes are not passed, so they have been omitted below

         if (bytes ~= "^BM")
            return "bmp"
         if (bytes ~= "^(GIF87a|GIF89a)")
            return "gif"
         if (bytes ~= "^ÿØÿÛ")
            return "jpg"
         if (bytes ~= "s)^ÿØÿà..\x4A\x46\x49\x46") ;\x00\x01
            return "jfif"
         if (bytes ~= "^\x89\x50\x4E\x47\x0D\x0A\x1A\x0A")
            return "png"
         if (bytes ~= "^(\x49\x49\x2A|\x4D\x4D\x2A)") ; 49 49 2A 00, 4D 4D 00 2A
            return "tif"
         return
      }

      isURL(url){
         regex .= "((https?|ftp)\:\/\/)" ; SCHEME
         regex .= "([a-z0-9+!*(),;?&=\$_.-]+(\:[a-z0-9+!*(),;?&=\$_.-]+)?@)?" ; User and Pass
         regex .= "([a-z0-9-.]*)\.([a-z]{2,3})" ; Host or IP
         regex .= "(\:[0-9]{2,5})?" ; Port
         regex .= "(\/([a-z0-9+\$_-]\.?)+)*\/?" ; Path
         regex .= "(\?[a-z+&\$_.-][a-z0-9;:@&%=+\/\$_.-]*)?" ; GET Query
         regex .= "(#[a-z_.-][a-z0-9+\$_.-]*)?" ; Anchor

         return (url ~= "i)" regex) ? true : false
      }

      b64Encode( ByRef buf, bufLen:="" ) {
         bufLen := (bufLen) ? bufLen : StrLen(buf) << !!A_IsUnicode
         DllCall( "crypt32\CryptBinaryToStringA", "ptr", &buf, "UInt", bufLen, "Uint", 1 | 0x40000000, "Ptr", 0, "UInt*", outLen )
         VarSetCapacity( outBuf, outLen, 0 )
         DllCall( "crypt32\CryptBinaryToStringA", "ptr", &buf, "UInt", bufLen, "Uint", 1 | 0x40000000, "Ptr", &outBuf, "UInt*", outLen )
         return strget( &outBuf, outLen, "CP0" )
      }

      b64Decode( b64str, ByRef outBuf ) {
         static CryptStringToBinary := "crypt32\CryptStringToBinary" (A_IsUnicode ? "W" : "A")

         DllCall( CryptStringToBinary, "ptr", &b64str, "UInt", 0, "Uint", 1, "Ptr", 0, "UInt*", outLen, "ptr", 0, "ptr", 0 )
         VarSetCapacity( outBuf, outLen, 0 )
         DllCall( CryptStringToBinary, "ptr", &b64str, "UInt", 0, "Uint", 1, "Ptr", &outBuf, "UInt*", outLen, "ptr", 0, "ptr", 0 )

         return outLen
      }

      CreateUUID() {
         VarSetCapacity(puuid, 16, 0)
         if !(DllCall("rpcrt4.dll\UuidCreate", "ptr", &puuid))
            if !(DllCall("rpcrt4.dll\UuidToString", "ptr", &puuid, "uint*", suuid))
               return StrGet(suuid), DllCall("rpcrt4.dll\RpcStringFree", "uint*", suuid)
         return ""
      }

      Gdip_EncodeBitmapTo64string(pBitmap, ext, Quality=75) {

         if Ext not in BMP,DIB,RLE,JPG,JPEG,JPE,JFIF,GIF,TIF,TIFF,PNG
               return -1
         Extension := "." Ext

         DllCall("gdiplus\GdipGetImageEncodersSize", "uint*", nCount, "uint*", nSize)
         VarSetCapacity(ci, nSize)
         DllCall("gdiplus\GdipGetImageEncoders", "uint", nCount, "uint", nSize, Ptr, &ci)
         if !(nCount && nSize)
            return -2



            Loop, %nCount%
            {
                  sString := StrGet(NumGet(ci, (idx := (48+7*A_PtrSize)*(A_Index-1))+32+3*A_PtrSize), "UTF-16")
                  if !InStr(sString, "*" Extension)
                     continue

                  pCodec := &ci+idx
                  break
            }


         if !pCodec
               return -3

         if (Quality != 75)
         {
               Quality := (Quality < 0) ? 0 : (Quality > 100) ? 100 : Quality
               if Extension in .JPG,.JPEG,.JPE,.JFIF
               {
                     DllCall("gdiplus\GdipGetEncoderParameterListSize", Ptr, pBitmap, Ptr, pCodec, "uint*", nSize)
                     VarSetCapacity(EncoderParameters, nSize, 0)
                     DllCall("gdiplus\GdipGetEncoderParameterList", Ptr, pBitmap, Ptr, pCodec, "uint", nSize, Ptr, &EncoderParameters)
                     Loop, % NumGet(EncoderParameters, "UInt")
                     {
                        elem := (24+(A_PtrSize ? A_PtrSize : 4))*(A_Index-1) + 4 + (pad := A_PtrSize = 8 ? 4 : 0)
                        if (NumGet(EncoderParameters, elem+16, "UInt") = 1) && (NumGet(EncoderParameters, elem+20, "UInt") = 6)
                        {
                              p := elem+&EncoderParameters-pad-4
                              NumPut(Quality, NumGet(NumPut(4, NumPut(1, p+0)+20, "UInt")), "UInt")
                              break
                        }
                     }
               }
         }

         DllCall("ole32\CreateStreamOnHGlobal", "ptr",0, "int",true, "ptr*",pStream)
         DllCall("gdiplus\GdipSaveImageToStream", "ptr",pBitmap, "ptr",pStream, "ptr",pCodec, "uint",p ? p : 0)

         DllCall("ole32\GetHGlobalFromStream", "ptr",pStream, "uint*",hData)
         pData := DllCall("GlobalLock", "ptr",hData, "uptr")
         nSize := DllCall("GlobalSize", "uint",pData)

         VarSetCapacity(Bin, nSize, 0)
         DllCall("RtlMoveMemory", "ptr",&Bin , "ptr",pData , "uint",nSize)
         DllCall("GlobalUnlock", "ptr",hData)
         DllCall(NumGet(NumGet(pStream + 0, 0, "uptr") + (A_PtrSize * 2), 0, "uptr"), "ptr",pStream)
         DllCall("GlobalFree", "ptr",hData)
         
         DllCall("Crypt32.dll\CryptBinaryToString", "ptr",&Bin, "uint",nSize, "uint",0x01, "ptr",0, "uint*",base64Length)
         VarSetCapacity(base64, base64Length*2, 0)
         DllCall("Crypt32.dll\CryptBinaryToString", "ptr",&Bin, "uint",nSize, "uint",0x01, "ptr",&base64, "uint*",base64Length)
         Bin := ""
         VarSetCapacity(Bin, 0)
         VarSetCapacity(base64, -1)

         return base64
      }

      Gdip_BitmapFromClientHWND(hwnd) {
         VarSetCapacity(rc, 16)
         DllCall("GetClientRect", "ptr", hwnd, "ptr", &rc)
      	hbm := CreateDIBSection(NumGet(rc, 8, "int"), NumGet(rc, 12, "int"))
         VarSetCapacity(rc, 0)
         hdc := CreateCompatibleDC()
         obm := SelectObject(hdc, hbm)
      	PrintWindow(hwnd, hdc, 1)
      	pBitmap := Gdip_CreateBitmapFromHBITMAP(hbm)
      	SelectObject(hdc, obm), DeleteObject(hbm), DeleteDC(hdc)
      	return pBitmap
      }

      Gdip_CropBitmap(ByRef pBitmap, c, preserveOriginal:=false){
         w := Gdip_GetImageWidth(pBitmap), h := Gdip_GetImageHeight(pBitmap)
         pBitmap2 := Gdip_CloneBitmapArea(pBitmap, c.1, c.2, (c.1 + c.3 > w) ? w - c.1 : c.3 , (c.2 + c.4 > h) ? h - c.2 : c.4)
         (preserveOriginal) ? "" : Gdip_DisposeImage(pBitmap)
         pBitmap := pBitmap2
      }

      Gdip_isBitmapEqual(pBitmap1, pBitmap2, width:="", height:="") {
         ; Check if pointers are identical.
         if (pBitmap1 == pBitmap2)
            return true

         ; Assume both Bitmaps are equal in width and height.
         width := (width) ? width : Gdip_GetImageWidth(pBitmap1)
         height := (height) ? height : Gdip_GetImageHeight(pBitmap1)
         E1 := Gdip_LockBits(pBitmap1, 0, 0, width, height, Stride1, Scan01, BitmapData1)
         E2 := Gdip_LockBits(pBitmap2, 0, 0, width, height, Stride2, Scan02, BitmapData2)

         ; RtlCompareMemory preforms an unsafe comparison stopping at the first different byte.
         length := width * height * 4  ; ARGB = 4 bytes
         bytes := DllCall("RtlCompareMemory", "ptr", Scan01+0, "ptr", Scan02+0, "uint", length)

         Gdip_UnlockBits(pBitmap1, BitmapData1)
         Gdip_UnlockBits(pBitmap2, BitmapData2)
         return (bytes == length) ? true : false
      }

      RPath_Absolute(AbsolutPath, RelativePath, s="\") {

         len := InStr(AbsolutPath, s, "", InStr(AbsolutPath, s . s) + 2) - 1   ;get server or drive string length
         pr := SubStr(AbsolutPath, 1, len)                                     ;get server or drive name
         AbsolutPath := SubStr(AbsolutPath, len + 1)                           ;remove server or drive from AbsolutPath
         If InStr(AbsolutPath, s, "", 0) = StrLen(AbsolutPath)                 ;remove last \ from AbsolutPath if any
            StringTrimRight, AbsolutPath, AbsolutPath, 1

         If InStr(RelativePath, s) = 1                                         ;when first char is \ go to AbsolutPath of server or drive
            AbsolutPath := "", RelativePath := SubStr(RelativePath, 2)        ;set AbsolutPath to nothing and remove one char from RelativePath
         Else If InStr(RelativePath,"." s) = 1                                 ;when first two chars are .\ add to current AbsolutPath directory
            RelativePath := SubStr(RelativePath, 3)                           ;remove two chars from RelativePath
         Else If InStr(RelativePath,".." s) = 1 {                              ;otherwise when first 3 char are ..\
            StringReplace, RelativePath, RelativePath, ..%s%, , UseErrorLevel     ;remove all ..\ from RelativePath
            Loop, %ErrorLevel%                                                    ;for all ..\
               AbsolutPath := SubStr(AbsolutPath, 1, InStr(AbsolutPath, s, "", 0) - 1)  ;remove one folder from AbsolutPath
         } Else                                                                ;relative path does not need any substitution
            pr := "", AbsolutPath := "", s := ""                              ;clear all variables to just return RelativePath

         Return, pr . AbsolutPath . s . RelativePath                           ;concatenate server + AbsolutPath + separator + RelativePath
      }

      setSystemCursor(CursorID = "", cx = 0, cy = 0 ) { ; Thanks to Serenity - https://autohotkey.com/board/topic/32608-changing-the-system-cursor/
         static SystemCursors := "32512,32513,32514,32515,32516,32640,32641,32642,32643,32644,32645,32646,32648,32649,32650,32651"

         Loop, Parse, SystemCursors, `,
         {
               Type := "SystemCursor"
               CursorHandle := DllCall( "LoadCursor", "uInt",0, "Int",CursorID )
               %Type%%A_Index% := DllCall( "CopyImage", "uInt",CursorHandle, "uInt",0x2, "Int",cx, "Int",cy, "uInt",0 )
               CursorHandle := DllCall( "CopyImage", "uInt",%Type%%A_Index%, "uInt",0x2, "Int",0, "Int",0, "Int",0 )
               DllCall( "SetSystemCursor", "uInt",CursorHandle, "Int",A_Loopfield)
         }
      }
   }

   class Text {

      copy() {
         AutoTrim Off
         c := ClipboardAll
         Clipboard := ""             ; Must start off blank for detection to work.
         Send, ^c
         ClipWait 0.5
         if ErrorLevel
            return
         t := Clipboard
         Clipboard := c
         VarSetCapacity(c, 0)
         return t
      }

      paste(t) {
         c := ClipboardAll
         Clipboard := t
         Send, ^v
         Sleep 50                    ; Don't change clipboard while it is pasted! (Sleep > 0)
         Clipboard := c
         VarSetCapacity(c, 0)        ; Free memory
         AutoTrim On
      }

      clipboard(data := ""){
         text := (data == "") ? Vis2.Text.copy() : data
         clipboard := text
         return text
      }

      google(data := "") {
         text := data
         if not RegExMatch(text, "^(http|ftp|telnet)")
            text := "https://www.google.com/search?&q=" . RegExReplace(text, "\s", "+")
         if (data)
            Run % text
         return data
      }
   }
}
