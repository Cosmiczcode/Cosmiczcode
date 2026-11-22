"""Packs src/ into SimulatorUI.rbxmx (drag-and-drop into Roblox Studio)."""
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
ITEMS = [
    ("ModuleScript", "SimUIConfig", "src/ReplicatedStorage/SimUIConfig.lua", "Move to ReplicatedStorage"),
    ("LocalScript", "SimUIClient", "src/StarterPlayerScripts/SimUIClient.client.lua", "Move to StarterPlayer > StarterPlayerScripts"),
    ("Script", "SimUIServer", "src/ServerScriptService/SimUIServer.server.lua", "Move to ServerScriptService"),
    ("ModuleScript", "TreadmillSkins", "src/ReplicatedStorage/TreadmillSkins.lua", "Move to ReplicatedStorage"),
    ("ModuleScript", "TreadmillConfig", "src/ReplicatedStorage/TreadmillConfig.lua", "Move to ReplicatedStorage"),
    ("ModuleScript", "WorldBuilder", "src/ReplicatedStorage/WorldBuilder.lua", "Move to ReplicatedStorage"),
    ("Script", "TreadmillServer", "src/ServerScriptService/TreadmillServer.server.lua", "Move to ServerScriptService"),
    ("LocalScript", "TreadmillClient", "src/StarterPlayerScripts/TreadmillClient.client.lua", "Move to StarterPlayer > StarterPlayerScripts"),
]

def item(ref, cls, name, src):
    code = (ROOT / src).read_text(encoding="utf-8").replace("]]>", "]]]]><![CDATA[>")
    return (f'<Item class="{cls}" referent="RBX{ref}"><Properties>'
            f'<string name="Name">{name}</string>'
            f'<ProtectedString name="Source"><![CDATA[{code}]]></ProtectedString>'
            f'</Properties></Item>')

body = "".join(item(i + 1, *x[:3]) for i, x in enumerate(ITEMS))
xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
       'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
       'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
       '<Item class="Folder" referent="RBX0"><Properties><string name="Name">SimulatorUI</string></Properties>'
       f'{body}</Item></roblox>')
(ROOT / "SimulatorUI.rbxmx").write_text(xml, encoding="utf-8")
print("wrote SimulatorUI.rbxmx")
