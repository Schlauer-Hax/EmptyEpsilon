#include "resources.h"
#include <packResourceProvider.h>
#include <preferenceManager.h>
#ifdef EE_APPLE_MOBILE
#include <SDL.h>
#endif


void initResourcePaths()
{
    string bundle_path;
#ifdef EE_APPLE_MOBILE
    char* base_path = SDL_GetBasePath();
    if (base_path)
    {
        bundle_path = string(base_path) + "data/";
        SDL_free(base_path);
    }
#endif
    if (PreferencesManager::get("mod") != "")
    {
        string mod = PreferencesManager::get("mod");
        if (getenv("HOME"))
        {
            new DirectoryResourceProvider(string(getenv("HOME")) + "/.emptyepsilon/resources/mods/" + mod);
            PackResourceProvider::addPackResourcesForDirectory(string(getenv("HOME")) + "/.emptyepsilon/resources/mods/" + mod);
        }
        new DirectoryResourceProvider(bundle_path + "resources/mods/" + mod);
        PackResourceProvider::addPackResourcesForDirectory(bundle_path + "resources/mods/" + mod);
    }

    new DirectoryResourceProvider(bundle_path + "resources/");
    new DirectoryResourceProvider(bundle_path + "scripts/");
    PackResourceProvider::addPackResourcesForDirectory(bundle_path + "packs/");
    if (getenv("HOME"))
    {
        new DirectoryResourceProvider(string(getenv("HOME")) + "/.emptyepsilon/resources/");
        new DirectoryResourceProvider(string(getenv("HOME")) + "/.emptyepsilon/scripts/");
        PackResourceProvider::addPackResourcesForDirectory(string(getenv("HOME")) + "/.emptyepsilon/packs/");
    }
#ifdef RESOURCE_BASE_DIR
    new DirectoryResourceProvider(RESOURCE_BASE_DIR "resources/");
    new DirectoryResourceProvider(RESOURCE_BASE_DIR "scripts/");
    PackResourceProvider::addPackResourcesForDirectory(RESOURCE_BASE_DIR "packs");
#endif
}
