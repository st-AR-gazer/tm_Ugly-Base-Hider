const string PluginName = Meta::ExecutingPlugin().Name;
const string PluginNameHash = Crypto::MD5(PluginName); // TODO: this isn't needed once you do the 2 below TODOs
const string MenuIconColor = "\\$" + PluginNameHash.SubStr(0, 3); // TODO: replace with "\\$f83" or whatever
const string PluginIcon = GetRandomIcon(PluginNameHash); // TODO: replace with a specific icon, e.g., Icons::Bath
const string MenuTitle = MenuIconColor + PluginIcon + "\\$z " + PluginName;

[Setting category="NoStadium Base Hider" name="Enabled (hide NoStadium base)"]
bool S_Enabled = true;

void Main() {
    WaitForNoMapLoaded();
    PrimeSavedMeshesOnce();
    if (S_Enabled) HideNoStadiumBase();
}

void OnDestroyed() {
    if (IsMapCurrentlyLoaded()) {
        NotifyWarning("Plugin unloaded while in a map. You may need to restart the game to restore the stadium base.");
        return;
    }
    ShowNoStadiumBase();
}

void WaitForNoMapLoaded() {
    while (IsMapCurrentlyLoaded()) {
        yield();
    }
}

bool IsMapCurrentlyLoaded() {
    auto app = GetApp();
    return app.RootMap !is null;
}

void HideNoStadiumBase() {
    // array indexes
    NullifyMesh(0);
    NullifyMesh(1);
    NullifyMesh(2);
    dev_trace("NoStadium base meshes hidden.");
}

void ShowNoStadiumBase() {
    if (!HasSavedMeshes()) {
        dev_trace("No saved NoStadium meshes to restore; skipping restore.");
        return;
    }
    RestoreMesh(0);
    RestoreMesh(1);
    RestoreMesh(2);
    dev_trace("NoStadium base meshes shown.");
}

const string NoStadiumBasePath = "GameData\\Stadium256\\Media\\Prefab\\Warp\\";
const string[] NoStadiumPrefabs = {"Border", "Corner", "Center"};
CSystemFidFile@[] NoStadiumPrefabFids = {null, null, null};
CPlugSolid2Model@[] NoStadiumMeshes = {null, null, null};

bool g_Primed = false;
void PrimeSavedMeshesOnce() {
    if (g_Primed) return;
    for (int i = 0; i < 3; i++) {
        if (NoStadiumMeshes[i] is null) {
            auto model = GetModelFromPrefab(i);
            if (model !is null && model.Mesh !is null) {
                @NoStadiumMeshes[i] = model.Mesh;
                NoStadiumMeshes[i].MwAddRef();
                GetPrefab(i).MwAddRef();
            }
        }
    }
    g_Primed = true;
}

void NullifyMesh(int index) {
    if (IsMeshNull(index)) return;
    SetMeshNull(index);
}

void RestoreMesh(int index) {
    if (!IsMeshNull(index)) return;
    SetMeshRestored(index);
}

bool IsMeshNull(int index) {
    return GetMeshFromPrefab(index) is null;
}

void SetMeshNull(int index) {
    auto model = GetModelFromPrefab(index);
    if (model is null) {
        Dev_NotifyWarning("Failed to get model for NoStadium" + NoStadiumPrefabs[index] + " prefab.");
        return;
    }
    if (model.Mesh is null) return;

    auto mesh = model.Mesh;

    // if we haven't saved the mesh, set ref and ref counts
    if (NoStadiumMeshes[index] is null) {
        @NoStadiumMeshes[index] = mesh;
        mesh.MwAddRef();
        GetPrefab(index).MwAddRef(); // prevent prefab from being unloaded
    }
    // clear mesh pointer
    Dev::SetOffset(model, O_STATIC_OBJ_MODEL_MESH, uint64(0));
}

void SetMeshRestored(int index) {
    if (NoStadiumMeshes[index] is null) {
        NotifyWarning("No stored mesh to restore for NoStadium" + NoStadiumPrefabs[index] + " prefab.");
        return;
    }
    auto model = GetModelFromPrefab(index);
    if (model is null) {
        Dev_NotifyWarning("Failed to get model for NoStadium" + NoStadiumPrefabs[index] + " prefab.");
        return;
    }

    if (model.Mesh !is null) return; // already restored

    Dev::SetOffset(model, O_STATIC_OBJ_MODEL_MESH, NoStadiumMeshes[index]);
}

CPlugSolid2Model@ GetMeshFromPrefab(int index) {
    auto model = GetModelFromPrefab(index);
    if (model is null) return null;
    return model.Mesh;
}

CPlugStaticObjectModel@ GetModelFromPrefab(int index) {
    CPlugPrefab@ prefab = GetPrefab(index);
    if (prefab is null) return null;
    if (prefab.Ents.Length == 0) return null;
    CPlugStaticObjectModel@ model = cast<CPlugStaticObjectModel>(prefab.Ents[0].Model);
    if (model is null) return null;
    return model;
}

CPlugPrefab@ GetPrefab(int index) {
    auto fid = GetPrefabFid(index);
    if (fid is null) return null;
    auto prefab = cast<CPlugPrefab>(Fids::Preload(fid));
    return prefab;
}

CSystemFidFile@ GetPrefabFid(int index) {
    if (NoStadiumPrefabFids[index] is null) {
        @NoStadiumPrefabFids[index] = Fids::GetGame(NoStadiumBasePath + "NoStadium" + NoStadiumPrefabs[index] + ".Prefab.Gbx");
    }
    return NoStadiumPrefabFids[index];
}

bool HasSavedMeshes() {
    return NoStadiumMeshes[0] !is null || NoStadiumMeshes[1] !is null || NoStadiumMeshes[2] !is null;
}
bool IsAllMeshesNull() {
    return IsMeshNull(0) && IsMeshNull(1) && IsMeshNull(2);
}

void ApplyFromSetting() {
    if (IsMapCurrentlyLoaded()) {
        NotifyWarning("Change queued: will apply after you leave the current map.");
    }
    WaitForNoMapLoaded();
    PrimeSavedMeshesOnce();

    const bool currentlyHidden = IsAllMeshesNull();
    if (S_Enabled) {
        if (!currentlyHidden) HideNoStadiumBase();
    } else {
        if (currentlyHidden && HasSavedMeshes()) ShowNoStadiumBase();
    }
}

void RenderMenu() {
    if (UI::MenuItem("Enabled (hide NoStadium base)", "", S_Enabled)) {
        S_Enabled = !S_Enabled;
        startnew(ApplyFromSetting);
    }
}


uint16 GetOffset(const string &in className, const string &in memberName) {
    auto ty = Reflection::GetType(className);
    return ty.GetMember(memberName).Offset;
}

const uint16 O_STATIC_OBJ_MODEL_MESH = GetOffset("CPlugStaticObjectModel", "Mesh");
