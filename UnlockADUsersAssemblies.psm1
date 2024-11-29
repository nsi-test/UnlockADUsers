[Void][reflection.assembly]::loadwithpartialname('System.Windows.Forms')
[Void][reflection.assembly]::loadwithpartialname('System.Drawing')
Add-Type -TypeDefinition @"
	using System;
	using System.Runtime.InteropServices;
	public class WinAPIFlash {
	[DllImport("user32.dll")]
	public static extern bool FlashWindow(IntPtr hwnd, bool bInvert);
	}
"@
#np++ inisists for this position of "@













