-- Lid switch → Isla (Settings → Power → "When I close the lid"). Isla holds a logind lid inhibitor
-- while it runs; if Isla isn't running, the IPC call fails and logind's default (sleep) applies.
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("qs -c isla ipc call isla lid closed"), { locked = true, description = "Lid closed" })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("qs -c isla ipc call isla lid open"), { locked = true, description = "Lid opened" })
