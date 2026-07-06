# Example development plugin — shows up in the Plugin browser (Menu > Plugins)
from Plugins.Plugin import PluginDescriptor
from Screens.MessageBox import MessageBox


def main(session, **kwargs):
    session.open(
        MessageBox,
        "Hello from the container!\n"
        "Edit container/plugins/HelloWorld/plugin.py on the host,\n"
        "then run ./gui-restart.sh",
        MessageBox.TYPE_INFO,
    )


def Plugins(**kwargs):
    return [
        PluginDescriptor(
            name="Hello World",
            description="Example development plugin",
            where=PluginDescriptor.WHERE_PLUGINMENU,
            fnc=main,
        )
    ]
