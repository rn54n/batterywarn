"""Fill BatteryWarn's App Store Connect entry from docs/store (idempotent).

    python3 -I batterywarn_store.py meta | shots [replace] | testflight | price | build | submit | status

Needs ASC_KEY_ID and ASC_ISSUER (see asc.py). Texts and pictures come from docs/store in this repo.
Optional: ASC_CONTACT_APP=<Apple ID of another app in the same account> takes over that app's review contact
and TestFlight feedback address. They only travel inside App Store Connect and are never printed.
"""
import hashlib, os, plistlib, sys, time, urllib.request
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from asc import call
from lib import ok, get_all

STORE = Path(__file__).resolve().parents[1]
BUNDLE_ID = "com.batterywarn.app"
LOCS = ("en-US", "de-DE")
COPYRIGHT = "2026 Aaren San"
CONTACT_APP = os.environ.get("ASC_CONTACT_APP")


def text(*parts):
    return (STORE / "metadata").joinpath(*parts).read_text(encoding="utf-8").strip()


def app_id():
    apps = [a for a in get_all(f"/v1/apps?filter[bundleId]={BUNDLE_ID}")[0] if a["attributes"]["bundleId"] == BUNDLE_ID]
    if not apps:
        raise SystemExit(f"No app record for {BUNDLE_ID} in App Store Connect yet")
    return apps[0]["id"]


def info_id(app):
    """The app info that can still be edited (a released app has a second, live one)."""
    infos = get_all(f"/v1/apps/{app}/appInfos")[0]
    live = ("READY_FOR_DISTRIBUTION", "READY_FOR_SALE")
    return next((i for i in infos if (i["attributes"].get("state") or i["attributes"].get("appStoreState")) not in live), infos[0])["id"]


def version_id(app):
    """The macOS version that is being prepared."""
    versions = get_all(f"/v1/apps/{app}/appStoreVersions?filter[platform]=MAC_OS")[0]
    if not versions:
        raise SystemExit("No macOS version in App Store Connect yet")
    return next((v for v in versions if v["attributes"].get("appStoreState") == "PREPARE_FOR_SUBMISSION"), versions[0])["id"]


def upsert(kind, parent_rel, parent_type, parent_id, list_path, loc, attrs):
    have = {d["attributes"]["locale"]: d["id"] for d in get_all(list_path)[0]}
    if loc in have:
        return ok(f"{kind} {loc}", *call("PATCH", f"/v1/{kind}/{have[loc]}", {"data": {"type": kind, "id": have[loc], "attributes": attrs}}))
    return ok(f"{kind} {loc}", *call("POST", f"/v1/{kind}", {"data": {"type": kind, "attributes": {"locale": loc, **attrs},
              "relationships": {parent_rel: {"data": {"type": parent_type, "id": parent_id}}}}}))


def upload(data, operations):
    for op in operations:
        req = urllib.request.Request(op["url"], data=data[op["offset"]:op["offset"] + op["length"]], method=op["method"],
                                     headers={h["name"]: h["value"] for h in op["requestHeaders"]})
        urllib.request.urlopen(req, timeout=300).read()


def review_contact():
    """Contact fields of another app in the same account, if one was named: from its App Store
    review details, else from its TestFlight review details."""
    if not CONTACT_APP:
        return {}
    paths = [f"/v1/appStoreVersions/{v['id']}/appStoreReviewDetail" for v in get_all(f"/v1/apps/{CONTACT_APP}/appStoreVersions?limit=5")[0]]
    for path in paths + [f"/v1/apps/{CONTACT_APP}/betaAppReviewDetail"]:
        s, src = call("GET", path)
        contact = {k: v for k, v in ((src.get("data") or {}).get("attributes") or {}).items()
                   if k in ("contactFirstName", "contactLastName", "contactEmail", "contactPhone") and v}
        if len(contact) == 4:
            return contact
    return {}


def meta():
    app = app_id()
    info, ver = info_id(app), version_id(app)
    ok("contentRights", *call("PATCH", f"/v1/apps/{app}", {"data": {"type": "apps", "id": app,
       "attributes": {"contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT"}}}))
    ok("categories", *call("PATCH", f"/v1/appInfos/{info}", {"data": {"type": "appInfos", "id": info, "relationships": {
       "primaryCategory": {"data": {"type": "appCategories", "id": "UTILITIES"}},
       "secondaryCategory": {"data": {"type": "appCategories", "id": "PRODUCTIVITY"}}}}}))
    for loc in LOCS:
        upsert("appInfoLocalizations", "appInfo", "appInfos", info, f"/v1/appInfos/{info}/appInfoLocalizations", loc,
               {"name": text(loc, "name.txt"), "subtitle": text(loc, "subtitle.txt"), "privacyPolicyUrl": text(loc, "privacy_url.txt")})
        upsert("appStoreVersionLocalizations", "appStoreVersion", "appStoreVersions", ver,
               f"/v1/appStoreVersions/{ver}/appStoreVersionLocalizations", loc,
               {"description": text(loc, "description.txt"), "keywords": text(loc, "keywords.txt"),
                "promotionalText": text(loc, "promotional_text.txt"), "supportUrl": text(loc, "support_url.txt"),
                "marketingUrl": text(loc, "marketing_url.txt")})
    # The store version has to carry the same number as the build that gets attached to it
    with open(STORE.parents[1] / "BatteryWarn" / "Info.plist", "rb") as f:
        version = plistlib.load(f)["CFBundleShortVersionString"]
    ok(f"version {version}, copyright", *call("PATCH", f"/v1/appStoreVersions/{ver}", {"data": {"type": "appStoreVersions", "id": ver,
       "attributes": {"versionString": version, "copyright": COPYRIGHT}}}))

    # Age rating: a battery warning. None of the content descriptors applies.
    s, j = call("GET", f"/v1/appInfos/{info}/ageRatingDeclaration")
    rating = j["data"]["id"]
    none = ["alcoholTobaccoOrDrugUseOrReferences", "contests", "gamblingSimulated", "gunsOrOtherWeapons",
            "medicalOrTreatmentInformation", "profanityOrCrudeHumor", "sexualContentGraphicAndNudity", "sexualContentOrNudity",
            "horrorOrFearThemes", "matureOrSuggestiveThemes", "violenceCartoonOrFantasy",
            "violenceRealisticProlongedGraphicOrSadistic", "violenceRealistic"]
    no = ["advertising", "gambling", "lootBox", "messagingAndChat", "parentalControls", "ageAssurance", "socialMedia",
          "unrestrictedWebAccess", "userGeneratedContent", "healthOrWellnessTopics"]
    attrs = {**{k: "NONE" for k in none}, **{k: False for k in no}}
    ok("ageRating", *call("PATCH", f"/v1/ageRatingDeclarations/{rating}", {"data": {"type": "ageRatingDeclarations", "id": rating, "attributes": attrs}}))

    contact = review_contact()
    detail = {**contact, "demoAccountRequired": False, "notes": text("review_notes.txt")}
    s, j = call("GET", f"/v1/appStoreVersions/{ver}/appStoreReviewDetail")
    if s == 200 and j.get("data"):
        rid = j["data"]["id"]
        ok("reviewDetail", *call("PATCH", f"/v1/appStoreReviewDetails/{rid}", {"data": {"type": "appStoreReviewDetails", "id": rid, "attributes": detail}}))
    else:
        ok("reviewDetail", *call("POST", "/v1/appStoreReviewDetails", {"data": {"type": "appStoreReviewDetails", "attributes": detail,
           "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": ver}}}}}))
    print("review contact fields taken over:", sorted(contact))


def shots():
    ver = version_id(app_id())
    files = sorted(p for p in (STORE / "screenshots").iterdir() if p.suffix in (".png", ".jpg"))
    locs, _ = get_all(f"/v1/appStoreVersions/{ver}/appStoreVersionLocalizations")
    for l in locs:
        loc, lid = l["attributes"]["locale"], l["id"]
        sets, _ = get_all(f"/v1/appStoreVersionLocalizations/{lid}/appScreenshotSets")
        st = next((s for s in sets if s["attributes"]["screenshotDisplayType"] == "APP_DESKTOP"), None)
        if not st:
            st = ok(f"set {loc}", *call("POST", "/v1/appScreenshotSets", {"data": {"type": "appScreenshotSets",
                "attributes": {"screenshotDisplayType": "APP_DESKTOP"},
                "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": lid}}}}}))["data"]
        sid = st["id"]
        if "replace" in sys.argv[2:]:          # new pictures under the same names: clear the set first
            for old in get_all(f"/v1/appScreenshotSets/{sid}/appScreenshots")[0]:
                ok(f"{loc} removed {old['attributes']['fileName']}", *call("DELETE", f"/v1/appScreenshots/{old['id']}"))
        names = {h["attributes"]["fileName"] for h in get_all(f"/v1/appScreenshotSets/{sid}/appScreenshots")[0]}
        for f in files:                        # the app is English only: one set of pictures for every language
            fname = f"batterywarn-{loc}-{f.name}"
            if fname in names:
                continue
            data = f.read_bytes()
            j = ok(f"{loc} {f.name}", *call("POST", "/v1/appScreenshots", {"data": {"type": "appScreenshots",
                "attributes": {"fileName": fname, "fileSize": len(data)},
                "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": sid}}}}}))
            if not j:
                continue
            upload(data, j["data"]["attributes"]["uploadOperations"])
            ok(f"{loc} {f.name} done", *call("PATCH", f"/v1/appScreenshots/{j['data']['id']}", {"data": {"type": "appScreenshots",
               "id": j["data"]["id"], "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}}))
    time.sleep(20)
    for l in locs:
        for s in get_all(f"/v1/appStoreVersionLocalizations/{l['id']}/appScreenshotSets")[0]:
            rows = get_all(f"/v1/appScreenshotSets/{s['id']}/appScreenshots")[0]
            print(l["attributes"]["locale"], s["attributes"]["screenshotDisplayType"],
                  [(x["attributes"]["fileName"][-12:], x["attributes"]["assetDeliveryState"]["state"]) for x in rows])


def testflight():
    app = app_id()
    feedback = None
    if CONTACT_APP:
        src = [d["attributes"] for d in get_all(f"/v1/apps/{CONTACT_APP}/betaAppLocalizations")[0]]
        feedback = next((a.get("feedbackEmail") for a in src if a.get("feedbackEmail")), None)
    for loc in LOCS:
        attrs = {"description": text("testflight", f"beta_description-{loc}.txt"), "marketingUrl": text(loc, "marketing_url.txt"),
                 "privacyPolicyUrl": text(loc, "privacy_url.txt")}
        if feedback:
            attrs["feedbackEmail"] = feedback
        upsert("betaAppLocalizations", "app", "apps", app, f"/v1/apps/{app}/betaAppLocalizations", loc, attrs)
    builds, _ = get_all(f"/v1/builds?filter[app]={app}&sort=-uploadedDate&limit=1")
    for b in builds[:1]:
        for loc in LOCS:
            upsert("betaBuildLocalizations", "build", "builds", b["id"], f"/v1/builds/{b['id']}/betaBuildLocalizations", loc,
                   {"whatsNew": text("testflight", f"what_to_test-{loc}.txt")})
    # Apple wants a contact before a build can go to external testers
    contact = review_contact()
    if contact:
        ok("betaAppReviewDetail", *call("PATCH", f"/v1/betaAppReviewDetails/{app}", {"data": {"type": "betaAppReviewDetails", "id": app,
           "attributes": {**contact, "demoAccountRequired": False, "notes": text("review_notes.txt")}}}))
    print("feedback address taken over:", bool(feedback), "| review contact fields taken over:", sorted(contact))


def price():
    """Free, in every country."""
    app = app_id()
    terr, _ = get_all("/v1/territories?limit=200")
    s, j = call("GET", f"/v1/appPriceSchedules/{app}/manualPrices?limit=200")
    if s == 200 and j.get("data"):
        print("price schedule exists:", len(j["data"]), "manual prices")
    else:
        pts, _ = get_all(f"/v1/apps/{app}/appPricePoints?filter%5Bterritory%5D=USA&limit=200")
        free = next(p for p in pts if float(p["attributes"]["customerPrice"]) == 0)["id"]
        ok("price free (base USA)", *call("POST", "/v1/appPriceSchedules", {"data": {"type": "appPriceSchedules",
           "relationships": {"app": {"data": {"type": "apps", "id": app}}, "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                             "manualPrices": {"data": [{"type": "appPrices", "id": "${p0}"}]}}},
           "included": [{"type": "appPrices", "id": "${p0}", "attributes": {"startDate": None},
                         "relationships": {"appPricePoint": {"data": {"type": "appPricePoints", "id": free}}}}]}))
    s, j = call("GET", f"/v1/apps/{app}/appAvailabilityV2")
    if s != 200:
        ids = [t["id"] for t in terr]
        ok("available in all countries", *call("POST", "/v2/appAvailabilities", {"data": {"type": "appAvailabilities",
           "attributes": {"availableInNewTerritories": True}, "relationships": {"app": {"data": {"type": "apps", "id": app}},
           "territoryAvailabilities": {"data": [{"type": "territoryAvailabilities", "id": f"${{t{i}}}"} for i in range(len(ids))]}}},
           "included": [{"type": "territoryAvailabilities", "id": f"${{t{i}}}", "attributes": {"available": True},
                         "relationships": {"territory": {"data": {"type": "territories", "id": t}}}} for i, t in enumerate(ids)]}))
    else:
        print("availability exists")


def build():
    """Attach the newest processed build to the App Store version. Until a build is attached,
    App Store Connect shows no app icon for the app."""
    app = app_id()
    newest = get_all(f"/v1/builds?filter[app]={app}&sort=-uploadedDate&limit=1")[0][0]
    if newest["attributes"]["processingState"] != "VALID":
        raise SystemExit(f"Build {newest['attributes']['version']} is not processed yet")
    ok(f"build {newest['attributes']['version']} attached", *call("PATCH", f"/v1/appStoreVersions/{version_id(app)}/relationships/build",
       {"data": {"type": "builds", "id": newest["id"]}}))


def submit():
    """Hand the prepared version to App Review. Once approved it goes on sale by itself."""
    app = app_id()
    ver = version_id(app)
    ok("release after approval", *call("PATCH", f"/v1/appStoreVersions/{ver}", {"data": {"type": "appStoreVersions", "id": ver,
       "attributes": {"releaseType": "AFTER_APPROVAL"}}}))
    waiting = get_all(f"/v1/apps/{app}/reviewSubmissions?filter[platform]=MAC_OS&filter[state]=READY_FOR_REVIEW")[0]
    if waiting:
        sub = waiting[0]["id"]
    else:
        sub = ok("review submission", *call("POST", "/v1/reviewSubmissions", {"data": {"type": "reviewSubmissions",
            "attributes": {"platform": "MAC_OS"}, "relationships": {"app": {"data": {"type": "apps", "id": app}}}}}))["data"]["id"]
    if not get_all(f"/v1/reviewSubmissions/{sub}/items")[0]:
        s, j = call("POST", "/v1/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems", "relationships": {
            "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub}},
            "appStoreVersion": {"data": {"type": "appStoreVersions", "id": ver}}}}})
        if s != 201:
            # Apple lists what is still missing in the associated errors
            for e in j.get("errors", []):
                print("ERR", e.get("code"), e.get("detail"))
                for path, more in ((e.get("meta") or {}).get("associatedErrors") or {}).items():
                    for m in more:
                        print("   ", path, "|", m.get("code"), "|", m.get("detail"))
            raise SystemExit(1)
        print("OK  version added to the submission")
    if not ok("submitted for review", *call("PATCH", f"/v1/reviewSubmissions/{sub}", {"data": {"type": "reviewSubmissions", "id": sub,
              "attributes": {"submitted": True}}})):
        raise SystemExit(1)


def status():
    app = app_id()
    info, ver = info_id(app), version_id(app)
    print("app", app)
    s, j = call("GET", f"/v1/appStoreVersions/{ver}?include=build")
    a = j["data"]["attributes"]
    print("version", a.get("versionString"), a.get("appStoreState"), "| copyright:", a.get("copyright"),
          "| build:", [b["attributes"].get("version") for b in j.get("included", [])])
    for l in get_all(f"/v1/appInfos/{info}/appInfoLocalizations")[0]:
        print(" ", l["attributes"]["locale"], l["attributes"]["name"], "|", l["attributes"].get("subtitle"), "|", l["attributes"].get("privacyPolicyUrl"))
    for l in get_all(f"/v1/appStoreVersions/{ver}/appStoreVersionLocalizations")[0]:
        a = l["attributes"]
        shots_ = [len(get_all(f"/v1/appScreenshotSets/{s['id']}/appScreenshots")[0])
                  for s in get_all(f"/v1/appStoreVersionLocalizations/{l['id']}/appScreenshotSets")[0]]
        print(" ", a["locale"], "description", len(a.get("description") or ""), "keywords", len(a.get("keywords") or ""),
              a.get("supportUrl"), "| screenshots", shots_)
    for b in get_all(f"/v1/builds?filter[app]={app}&sort=-uploadedDate&limit=3")[0]:
        print("  build", b["attributes"]["version"], b["attributes"]["processingState"], b["attributes"].get("uploadedDate"))


if __name__ == "__main__":
    {"meta": meta, "shots": shots, "testflight": testflight, "price": price, "build": build, "submit": submit,
     "status": status}[sys.argv[1]]()
