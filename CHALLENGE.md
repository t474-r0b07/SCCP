```
[!] POSITION ANOMALY DETECTED
    source: /var/log/gps_feed.log
    timestamp: 2017-06-22T11:43:17Z
    confidence: ████░░░░░░ 40%
```

---

```
something in the README gave you coordinates.
coordinates that don't match reality.
that's the point.
```

---

## `> cat intercepted_signal.raw`

```
G&C+bH!(NDupmw>ATu{EH#9ji!muDk
```

```
encoding: base85
layer 1 of 2
```

---

## `> ./decode.sh --layer 1`

```
hint: base85 is not base64.
      look it up if you need to.
      the tools exist.

      python3 -c "import base64; print(base64.b85decode('...').decode())"
```

---

## `> ./locate.sh`

```
you now have coordinates.
plot them.
not in a simulator — in the real world.

what is at that location?
not a city. not a country.
the specific place.
the name that history recorded.
```

---

## `> ./verify.sh --layer 2`

```
take the name of what you found.
lowercase. no spaces. no accents.

sha1(name)[:8]

if the result is:  f4559b60
you found it.
```

---

```
[?] why this place?

    in 2017, more than 20 vessels in the Black Sea
    reported their GPS position as this location.
    they were not there.
    nobody was jamming them.
    someone was feeding them a false signal.

    the ships trusted the data.
    the data was wrong.

    SCCP was built so that doesn't happen here.
```

---

```
[✓] if sha1(your_answer)[:8] == f4559b60 :

    you understand why GPS spoofing detection
    is not a feature. it's a requirement.

    >> https://www.youtube.com/@t474-r0b07
```

---

```
[SIGNAL LOST]
```
