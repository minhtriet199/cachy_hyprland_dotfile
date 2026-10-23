-- Lid switch → Island (Settings → Power → "When I close the lid"). Island holds a logind lid inhibitor
-- while it runs; if Island isn't running, the IPC call fails and logind's default (sleep) applies.
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("qs -c island ipc call island lid closed"), { locked = true, description = "Lid closed" })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("qs -c island ipc call island lid open"), { locked = true, description = "Lid opened" })
