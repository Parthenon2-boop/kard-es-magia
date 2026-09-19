// Kard és Mágia – asztali ablak a játéknak (Electron)
// A játék maga az index.html; ez a fájl csak egy saját ablakot nyit neki, böngésző nélkül.
// F11: teljes képernyő ki/be.

const { app, BrowserWindow, Menu, shell } = require("electron");
const path = require("path");

app.commandLine.appendSwitch("autoplay-policy", "no-user-gesture-required");

function createWindow() {
	const win = new BrowserWindow({
		width: 1280,
		height: 800,
		minWidth: 900,
		minHeight: 600,
		title: "Kard és Mágia",
		backgroundColor: "#080604",
		icon: path.join(__dirname, "build", "icon.png"),
		autoHideMenuBar: true,
		show: false,
		webPreferences: {
			contextIsolation: true,
			nodeIntegration: false,
			sandbox: true,
		},
	});
	Menu.setApplicationMenu(null);
	win.once("ready-to-show", () => win.show());
	win.loadFile(path.join(__dirname, "index.html"));

	// a játék nem navigálhat el, és új ablakot sem nyithat
	win.webContents.on("will-navigate", (e) => e.preventDefault());
	win.webContents.setWindowOpenHandler(({ url }) => {
		if (url.startsWith("https://")) shell.openExternal(url);
		return { action: "deny" };
	});
	win.webContents.on("before-input-event", (e, input) => {
		if (input.type === "keyDown" && input.key === "F11") {
			win.setFullScreen(!win.isFullScreen());
			e.preventDefault();
		}
	});
	win.on("page-title-updated", (e) => e.preventDefault());
}

app.whenReady().then(createWindow);
app.on("window-all-closed", () => app.quit());
