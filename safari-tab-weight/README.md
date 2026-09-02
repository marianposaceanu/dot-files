# Tab Weight

A privacy-conscious Safari Web Extension that measures the observable weight of the current tab when its toolbar button is clicked.

## What it reports

- a Low, Medium, Heavy, or Ultra estimate of the page's observable weight
- transferred and decoded resource sizes exposed by the Resource Timing API
- request counts and a resource-type breakdown
- DOM elements, scripts, images, stylesheets, and frames
- DOMContentLoaded and load-event timing
- the controlling Service Worker and same-origin Service Worker registrations

The extension does not run in the background, retain data, or send data anywhere. Its only permissions are `activeTab` and `scripting`, so it inspects a page only after the toolbar button is clicked.

The popup takes one bounded snapshot and does not install content scripts, timers, observers, or background workers. Closing the popup destroys its JavaScript context.

## Weight estimate

Each signal first receives a band from 0 (Low) through 3 (Ultra). Tab Weight then applies more influence to active JavaScript than to static structure or media because JavaScript must also be parsed, compiled, and executed. It is a footprint estimate, not a Lighthouse performance score or a direct measurement of speed, CPU, or memory.

| Signal | Influence | Low | Medium | Heavy | Ultra |
| --- | ---: | ---: | ---: | ---: | ---: |
| JavaScript payload | 4× | ≤ 300 KB | ≤ 700 KB | ≤ 2 MB | > 2 MB |
| Script requests | 3× | ≤ 11 | ≤ 23 | ≤ 67 | > 67 |
| Resource payload | 1× | ≤ 1.25 MB | ≤ 2.5 MB | ≤ 5 MB | > 5 MB |
| Requests | 1× | ≤ 45 | ≤ 77 | ≤ 185 | > 185 |
| DOM elements | 1× | ≤ 342 | ≤ 800 | ≤ 1,400 | > 1,400 |

The weighted points map to Low (0–1), Medium (2–7), Heavy (8–17), and Ultra (18 or more). The JavaScript-payload band is also a minimum rating, so a Heavy JavaScript payload can never be averaged below Heavy. Ultra script-request or DOM counts produce at least Heavy, while a page that is Ultra in DOM, requests, and resource payload is Ultra even without JavaScript.

The byte and request bands are rounded from the [2025 HTTP Archive Web Almanac page-weight distributions](https://almanac.httparchive.org/en/2025/page-weight), which also explains why JavaScript carries a performance tax greater than its file size. Its desktop percentiles include 1,275 KB / 2,412 KB / 4,570 KB for total payload, 303 KB / 708 KB / 2,003 KB for JavaScript, 46 / 77 / 185 total requests, and 11 / 23 / 67 JavaScript requests. The 5 MB boundary also matches [Lighthouse's enormous-network-payload warning](https://developer.chrome.com/docs/lighthouse/performance/total-byte-weight/).

The DOM bands combine the [2024 Web Almanac element distribution](https://almanac.httparchive.org/en/2024/markup#elements) with [Lighthouse's DOM guidance](https://developer.chrome.com/docs/lighthouse/performance/dom-size/): approximately 342 elements is the 25th percentile, Lighthouse warns around 800, and it treats more than roughly 1,400 as excessive.

## Browser limits

Safari does not give extensions per-tab process CPU or RAM, so Tab Weight omits those values. Web APIs also do not allow a page to enumerate its existing dedicated or shared Web Workers; the popup states that limit instead of estimating an unsupported value.

Resource sizes are best-effort. The classifier uses the compressed resource-body size when Safari exposes it, falling back to transferred size. Cached resources and cross-origin resources without appropriate timing headers can report zero, so the popup shows measurement coverage alongside the totals. Missing sizes can make the estimate lower than the page's real weight, but they cannot increase it. Measurements cover the top-level document, not cross-origin frame internals.

## Run in Safari

Open [`xcode/Tab Weight/Tab Weight.xcodeproj`](xcode/Tab%20Weight/Tab%20Weight.xcodeproj) in Xcode. Choose a development team for the app and extension targets, build and run the macOS app, then enable **Tab Weight** in **Safari → Settings → Extensions**. Safari may ask which websites the extension can access; access is needed only for the tab being measured.

The generated Xcode project references the portable files in [`extension`](extension), so changes there are included automatically. To rebuild the wrapper with Xcode 26.6 without changing the system-wide developer-directory selection, run from this directory:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun safari-web-extension-packager \
  --project-location ./xcode \
  --app-name "Tab Weight" \
  --bundle-identifier com.marian.Tab-Weight \
  --swift --macos-only --force --no-open --no-prompt \
  ./extension
```

Apple previously named the tool `safari-web-extension-converter`. Current Xcode releases call it `safari-web-extension-packager`.
