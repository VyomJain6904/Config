package calendar

import (
	"testing"
	"time"
)

func TestEventRangeForRequestedMonth(t *testing.T) {
	minimum, maximum := eventRange("7", "2026")
	if minimum != "2026-07-01T00:00:00Z" {
		t.Fatalf("minimum = %q", minimum)
	}
	if maximum != "2026-08-01T00:00:00Z" {
		t.Fatalf("maximum = %q", maximum)
	}
}

func TestEventMonthNormalizesRequestedMonth(t *testing.T) {
	key, month, year := eventMonth("7", "2026")
	if key != "2026-07" || month != 7 || year != 2026 {
		t.Fatalf("eventMonth() = %q, %d, %d", key, month, year)
	}
}

func TestMonthFromDate(t *testing.T) {
	if month := monthFromDate("2026-07-27"); month != "2026-07" {
		t.Fatalf("monthFromDate() = %q", month)
	}
	if month := monthFromDate("invalid"); month != "" {
		t.Fatalf("monthFromDate(invalid) = %q", month)
	}
}

func TestParseEventStartUsesLocalTime(t *testing.T) {
	original := time.Local
	time.Local = time.FixedZone("IST", 5*60*60+30*60)
	t.Cleanup(func() { time.Local = original })

	date, clock := parseEventStart("2026-07-27T00:00:00Z", "")
	if date != "2026-07-27" || clock != "05:30 AM" {
		t.Fatalf("parseEventStart() = %q, %q", date, clock)
	}
}

func TestParseAllDayEvent(t *testing.T) {
	date, clock := parseEventStart("", "2026-07-27")
	if date != "2026-07-27" || clock != "" {
		t.Fatalf("parseEventStart() = %q, %q", date, clock)
	}
}
