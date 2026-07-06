# MacKeymap ships no screens — it exists only so PluginComponent picks up the
# keymap.xml sitting next to this file (loaded additively at GUI start).


def Plugins(**kwargs):
    return []
