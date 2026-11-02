#!/usr/bin/env python3
"""Read-only calendar fetcher for Evolution Data Server.

Reads the calendars selected in GNOME Calendar (local and remote/CalDAV) and
prints a JSON agenda for the requested date range. Recurring events are
expanded by EDS itself, so the output contains real occurrences.
"""

import argparse
import datetime as dt
import fcntl
import json
import os
import sys
import tempfile

DEFAULT_OUTPUT = os.path.expanduser("~/.local/state/bnsplit/calendar.json")
DEFAULT_LOCK = os.path.expanduser("~/.local/state/bnsplit/calendar.lock")
PAYLOAD_VERSION = 2


def parse_args():
    parser = argparse.ArgumentParser(description="Fetch calendar events from Evolution Data Server")
    parser.add_argument("--start", help="Start date, inclusive (YYYY-MM-DD)")
    parser.add_argument("--end", help="End date, exclusive (YYYY-MM-DD)")
    parser.add_argument("--month", help="Fetch a whole month (YYYY-MM)")
    parser.add_argument("--key", help="Opaque cache key echoed back in the output")
    parser.add_argument("--output", default=DEFAULT_OUTPUT, help="JSON output file")
    parser.add_argument("--lock", default=DEFAULT_LOCK, help="Lock file")
    return parser.parse_args()


def parse_range(args):
    if args.month:
        if args.start or args.end:
            raise ValueError("--month cannot be combined with --start/--end")
        year, month = (int(part) for part in args.month.split("-", 1))
        start = dt.date(year, month, 1)
        end = dt.date(year + (month == 12), (month % 12) + 1, 1)
        return start, end
    if not args.start or not args.end:
        today = dt.date.today()
        start = today.replace(day=1)
        end = dt.date(today.year + (today.month == 12), (today.month % 12) + 1, 1)
        return start, end
    start = dt.date.fromisoformat(args.start)
    end = dt.date.fromisoformat(args.end)
    if end <= start:
        raise ValueError("--end must be after --start")
    return start, end


def local_day(epoch):
    return dt.datetime.fromtimestamp(epoch).date()


def local_midnight(day):
    return int(dt.datetime.combine(day, dt.time.min).timestamp())


def utc_query_time(epoch):
    return dt.datetime.fromtimestamp(epoch, dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def time_range_query(start_epoch, end_epoch):
    return (
        "(occur-in-time-range? "
        f'(make-time "{utc_query_time(start_epoch)}") '
        f'(make-time "{utc_query_time(end_epoch)}"))'
    )


def recurrence_id(component):
    recurrence = component.get_recurrenceid()
    if recurrence is None:
        return ""
    try:
        if recurrence.is_null_time():
            return ""
    except Exception:
        return ""
    return recurrence.as_ical_string()


def format_iso(epoch):
    return dt.datetime.fromtimestamp(epoch, dt.timezone.utc).astimezone().isoformat(timespec="seconds")


def acquire_lock(path):
    directory = os.path.dirname(path)
    if directory:
        os.makedirs(directory, exist_ok=True)
    fd = os.open(path, os.O_CREAT | os.O_RDWR, 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        os.close(fd)
        return None
    return fd


def write_json(path, payload):
    directory = os.path.dirname(path)
    if directory:
        os.makedirs(directory, exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(dir=directory or ".", prefix=".calendar-", suffix=".json")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
        os.replace(tmp_path, path)
    finally:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)


def prop_value(component, kind):
    prop = component.get_first_property(kind)
    return prop.get_value_as_string() if prop is not None else ""


def build_event(component, start_time, end_time, calendar, ical):
    status = prop_value(component, ical.PropertyKind.STATUS_PROPERTY).upper()
    if status == "CANCELLED":
        return None

    uid = component.get_uid() or ""
    summary = component.get_summary() or ""
    description = component.get_description() or ""
    location = component.get_location() or ""
    url = prop_value(component, ical.PropertyKind.URL_PROPERTY)
    transparent = prop_value(component, ical.PropertyKind.TRANSP_PROPERTY).upper() == "TRANSPARENT"

    dtstart = component.get_dtstart()
    dtend = component.get_dtend()
    if dtstart is None and start_time is None:
        return None

    all_day = bool(dtstart is not None and dtstart.is_date())
    if all_day:
        start_day = dt.date(dtstart.get_year(), dtstart.get_month(), dtstart.get_day())
        if dtend is not None and dtend.is_date():
            end_day = dt.date(dtend.get_year(), dtend.get_month(), dtend.get_day())
        else:
            end_day = start_day + dt.timedelta(days=1)
        if end_day <= start_day:
            end_day = start_day + dt.timedelta(days=1)
        start_epoch = local_midnight(start_day)
        end_epoch = local_midnight(end_day)
        last_day = end_day - dt.timedelta(days=1)
    else:
        if start_time is not None:
            start_epoch = int(start_time.as_timet())
        elif dtstart is not None:
            start_epoch = int(dtstart.as_timet())
        else:
            return None
        if end_time is not None:
            end_epoch = int(end_time.as_timet())
        elif dtend is not None:
            end_epoch = int(dtend.as_timet())
        else:
            end_epoch = start_epoch
        if end_epoch <= start_epoch:
            end_epoch = start_epoch + 1
        start_day = local_day(start_epoch)
        last_day = local_day(end_epoch - 1)

    recurrence = component.get_recurrenceid()
    recurrence_id = ""
    if recurrence is not None:
        try:
            if not recurrence.is_null_time():
                recurrence_id = recurrence.as_ical_string()
        except Exception:
            pass

    event = {
        "id": f"{calendar['uid']}:{uid}:{recurrence_id or start_epoch}",
        "uid": uid,
        "summary": summary,
        "description": description,
        "location": location,
        "url": url,
        "start": format_iso(start_epoch),
        "end": format_iso(end_epoch),
        "startEpoch": start_epoch,
        "endEpoch": end_epoch,
        "allDay": all_day,
        "multiDay": start_day != last_day,
        "calendarUid": calendar["uid"],
        "calendarName": calendar["name"],
        "calendarColor": calendar["color"],
        "status": status or "CONFIRMED",
        "transparent": transparent,
    }
    return event, start_day, last_day


def fetch(start_date, end_date, key):
    payload = {
        "available": False,
        "version": PAYLOAD_VERSION,
        "key": key,
        "generated_at": dt.datetime.now().astimezone().isoformat(timespec="seconds"),
        "window": {"start": start_date.isoformat(), "end": end_date.isoformat()},
        "calendars": [],
        "days": [],
        "events": [],
        "errors": [],
    }

    try:
        import gi
        gi.require_version("EDataServer", "1.2")
        gi.require_version("ECal", "2.0")
        gi.require_version("ICalGLib", "4.0")
        from gi.repository import ECal, EDataServer, ICalGLib
    except Exception as exc:
        payload["error"] = f"Evolution Data Server bindings unavailable: {exc}"
        return payload

    try:
        registry = EDataServer.SourceRegistry.new_sync(None)
    except Exception as exc:
        payload["error"] = f"Could not open the Evolution source registry: {exc}"
        return payload
    if registry is None:
        payload["error"] = "Could not open the Evolution source registry"
        return payload

    payload["available"] = True
    start_epoch = local_midnight(start_date)
    end_epoch = local_midnight(end_date)
    days = {}
    flat_events = []

    try:
        sources = registry.list_sources(EDataServer.SOURCE_EXTENSION_CALENDAR)
    except Exception as exc:
        payload["error"] = f"Could not list calendar sources: {exc}"
        payload["available"] = False
        return payload

    for source in sources:
        try:
            extension = source.get_extension(EDataServer.SOURCE_EXTENSION_CALENDAR)
            if extension is None or not source.get_enabled() or not extension.get_selected():
                continue
        except Exception as exc:
            payload["errors"].append(f"{source.get_uid()}: {exc}")
            continue

        calendar = {
            "uid": source.get_uid(),
            "name": source.get_display_name() or source.get_uid(),
            "color": extension.get_color() or "",
            "backend": extension.get_backend_name() or "",
        }
        payload["calendars"].append(calendar)

        try:
            client = ECal.Client.connect_sync(source, ECal.ClientSourceType.EVENTS, 5, None)
        except Exception as exc:
            payload["errors"].append(f"{calendar['uid']}: {exc}")
            continue
        if client is None:
            payload["errors"].append(f"{calendar['uid']}: calendar backend unavailable")
            continue

        try:
            ok, components = client.get_object_list_sync(
                time_range_query(start_epoch, end_epoch), None
            )
        except Exception as exc:
            payload["errors"].append(f"{calendar['uid']}: {exc}")
            continue
        if not ok:
            payload["errors"].append(f"{calendar['uid']}: could not list calendar objects")
            continue

        masters = []
        exceptions = []
        for component in components or []:
            try:
                if component.get_component_name() != "VEVENT":
                    continue
            except Exception:
                continue
            source_recurrence_id = recurrence_id(component)
            if source_recurrence_id:
                exceptions.append((component, source_recurrence_id))
            else:
                masters.append(component)

        instances = {}

        def add_instances(component, source_recurrence_id=""):
            source_uid = component.get_uid() or ""

            def on_instance(instance, instance_start, instance_end, *_rest):
                try:
                    built = build_event(instance, instance_start, instance_end, calendar, ICalGLib)
                except Exception as exc:
                    payload["errors"].append(f"{calendar['uid']}: {exc}")
                    return
                if not built:
                    if source_recurrence_id:
                        instances.pop((calendar["uid"], source_uid, source_recurrence_id), None)
                    return
                event, first_day, last_day = built
                if source_recurrence_id:
                    key = (calendar["uid"], event["uid"], source_recurrence_id)
                else:
                    instance_recurrence_id = recurrence_id(instance)
                    key = (
                        calendar["uid"],
                        event["uid"],
                        instance_recurrence_id or event["startEpoch"],
                    )
                instances[key] = (event, first_day, last_day)

            try:
                client.generate_instances_for_object_sync(
                    component, start_epoch, end_epoch, None, on_instance, None
                )
            except Exception as exc:
                payload["errors"].append(f"{calendar['uid']}: {exc}")

        for component in masters:
            add_instances(component)
        for component, source_recurrence_id in exceptions:
            add_instances(component, source_recurrence_id)

        for event, first_day, last_day in instances.values():
            flat_events.append(event)
            current = first_day
            while current <= last_day:
                if start_date <= current < end_date:
                    days.setdefault(current.isoformat(), []).append(event)
                current += dt.timedelta(days=1)

    def event_order(event):
        return (0 if event["allDay"] else 1, event["startEpoch"], event["summary"].lower())

    payload["days"] = [
        {"date": date, "events": sorted(days[date], key=event_order)}
        for date in sorted(days)
    ]
    payload["events"] = sorted(flat_events, key=event_order)
    return payload


def main():
    args = parse_args()
    try:
        start_date, end_date = parse_range(args)
    except ValueError as exc:
        print(json.dumps({"available": False, "error": str(exc)}))
        return 2

    lock_fd = acquire_lock(args.lock)
    if lock_fd is None:
        print(json.dumps({"skipped": True, "reason": "locked"}))
        return 0

    try:
        payload = fetch(start_date, end_date, args.key)
        write_json(args.output, payload)
        print(json.dumps(payload, ensure_ascii=False))
        return 0 if payload.get("available") else 1
    finally:
        os.close(lock_fd)


if __name__ == "__main__":
    sys.exit(main())
