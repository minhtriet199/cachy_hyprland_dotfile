import QtQuick
import Quickshell
import Quickshell.Io

// Part of Services: weather from wttr.in (JSON) every 30 min. Use it through Services.weather / refreshWeather().
Scope {
    id: w
    property string city: ""                 // "" = wttr.in guesses from your IP
    property var weather: ({ temp: "--", glyph: "cloud", ok: false })
    function wxGlyph(desc, hour) {
        const c = (desc || "").toLowerCase();
        if (c.includes("rain") || c.includes("drizzle") || c.includes("shower") || c.includes("thunder")) return "rain";
        if (c.includes("sun") || c.includes("clear")) return hour >= 18 || hour < 6 ? "moon" : "sun";
        return "cloud";
    }
    // wttr's place names arrive as UTF-8 read byte by byte → put the letters back together ("Đa Kao")
    function utf8(x) { try { return decodeURIComponent(escape(x)) } catch (e) { return x } }
    function refreshWeather() { if (!wx.running) wx.running = true }
    Process { id: wx; command: ["curl", "-s", "--max-time", "10", "https://wttr.in/" + w.city + "?format=j1"]
        stdout: StdioCollector { onStreamFinished: {
            let d; try { d = JSON.parse(this.text) } catch (e) { return }
            const c = d.current_condition && d.current_condition[0]; if (!c) return;
            const desc = c.weatherDesc && c.weatherDesc[0] ? c.weatherDesc[0].value : "";
            const now = new Date(), dn = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], mn = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
            const days = (d.weather || []).slice(0, 3).map((w, i) => {
                const dt = new Date(w.date + "T12:00:00");
                return { label: i === 0 ? "Today" : dn[dt.getDay()] + " " + dt.getDate(), max: parseInt(w.maxtempC), min: parseInt(w.mintempC),
                         rain: Math.max(...w.hourly.map(h => parseInt(h.chanceofrain) || 0)) };
            });
            const hours = [];
            for (const [i, w] of (d.weather || []).slice(0, 2).entries())
                for (const h of w.hourly) {
                    const hr = Math.floor(parseInt(h.time) / 100), dt = new Date(w.date + "T00:00:00"); dt.setHours(hr);
                    if (dt.getTime() > now.getTime() - 3600000 && hours.length < 3)
                        hours.push({ label: (hr % 12 || 12) + (hr < 12 ? " AM" : " PM"), temp: parseInt(h.tempC), rain: parseInt(h.chanceofrain) || 0 });
                }
            // hourly line for the weather card: the next 8 three-hour slots (wttr gives 0:00, 3:00 … 21:00 per day)
            const line = [];
            for (const wd of (d.weather || []).slice(0, 2))
                for (const h of wd.hourly) {
                    const hr = Math.floor(parseInt(h.time) / 100), dt = new Date(wd.date + "T00:00:00"); dt.setHours(hr);
                    if (dt.getTime() > now.getTime() - 3 * 3600000 && line.length < 8) {
                        const hd = h.weatherDesc && h.weatherDesc[0] ? h.weatherDesc[0].value : "";
                        line.push({ label: (hr < 10 ? "0" : "") + hr + ":00", temp: parseInt(h.tempC), glyph: w.wxGlyph(hd, hr) });
                    }
                }
            const na = d.nearest_area && d.nearest_area[0], av = (k) => na && na[k] && na[k][0] ? w.utf8(na[k][0].value) : "";
            const area = [av("areaName"), av("country")].filter(x => x).join(", ");
            w.weather = { ok: true, line: line, area: area, windDeg: parseInt(c.winddirDegree) || 0, windDir: c.winddir16Point || "", temp: c.temp_C + "°C", tempN: parseInt(c.temp_C), glyph: w.wxGlyph(desc, now.getHours()), desc: desc,
                          max: days.length ? days[0].max : 0, min: days.length ? days[0].min : 0,
                          humidity: c.humidity, wind: c.windspeedKmph, uv: c.uvIndex, feels: c.FeelsLikeC, pressure: c.pressure, visibility: c.visibility,
                          days: days, hours: hours, updated: now };
        } } }
    Timer { interval: 30 * 60 * 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: wx.running = true }
}
