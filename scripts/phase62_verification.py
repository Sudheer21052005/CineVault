"""Capture live full filmographies and exercise shared view, sort, and filter state."""
import argparse
import json
from pathlib import Path

from phase1_web_benchmark import chrome, serve
from phase3_web_verification import control, document, screenshot, seek, tap


ACTORS = [
    (18897, 'chan', ['Rush Hour', 'Police Story', 'Project A', 'Drunken Master']),
    (976, 'statham', ['The Transporter', 'Snatch', 'Crank', 'The Beekeeper']),
]


def top_cards(browser):
    return browser.evaluate("""(() => {
      const labels = [];
      function scan(root) {
        for (const node of root.querySelectorAll('[role=button]')) {
          const label = node.getAttribute('aria-label') || node.textContent.trim();
          if (/ (Film|TV) · /.test(label)) labels.push(label);
        }
        for (const host of root.querySelectorAll('flt-glass-pane, flt-scene-host, flt-semantics-host'))
          if (host.shadowRoot) scan(host.shadowRoot);
      }
      scan(document);
      return [...new Set(labels)].slice(0, 7);
    })()""")


def wait_query(browser, part):
    browser.wait(lambda: browser.evaluate(f'location.hash.includes({part!r})'), part)


def verify(browser, out):
    for actor, slug, substantial in ACTORS:
        uri = f'/person/{actor}/filmography'
        document(browser, uri, 'Relevance')
        seek(browser, 'Grid', exact=True)
        screenshot(browser, out, f'{slug}-relevance')
        cards = top_cards(browser)
        assert cards and any(title in card for title in substantial for card in cards), cards
        assert all('Self - Guest' not in card and 'Talk Show' not in card for card in cards[:5]), cards
        print(slug, 'relevance', json.dumps(cards), flush=True)
        tap(browser, 'Relevance')
        tap(browser, 'Popularity')
        wait_query(browser, 'sort=popularity')
        screenshot(browser, out, f'{slug}-popularity')
        cards = top_cards(browser)
        assert cards and sum('Self - Guest' in card for card in cards[:5]) == 0, cards
        print(slug, 'popularity', json.dumps(cards), flush=True)
        tap(browser, 'All media')
        tap(browser, 'TV shows', exact=True, role='')
        wait_query(browser, 'kind=tv')
        tap(browser, 'List', exact=True)
        screenshot(browser, out, f'{slug}-filtered-list')
        assert not top_cards(browser)
        tap(browser, 'Grid', exact=True)
        cards = browser.wait(lambda: top_cards(browser), 'filtered poster cards')
        assert all(' TV · ' in card for card in cards)
        wait_query(browser, 'sort=popularity')
        wait_query(browser, 'kind=tv')
    document(browser, '/person/976/filmography', 'Relevance', width=390, height=844)
    seek(browser, 'List', exact=True)
    assert not top_cards(browser)
    tap(browser, 'Grid', exact=True)
    browser.wait(lambda: top_cards(browser), 'mobile poster cards')
    screenshot(browser, out, 'statham-mobile-grid')
    print('Responsive defaults, both views, combined TV filter and sorting passed.', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--chrome', required=True)
    parser.add_argument('--build', required=True, type=Path)
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    with serve(args.build, False) as origin, chrome(args.chrome, origin, False) as browser:
        verify(browser, args.out)
