/*
 * sensors.cpp - Layer 2: sensor service over the board drivers (see sensors.h).
 */
#include "sensors.h"

uint8_t sensors_init()
{
    uint8_t n = 0;
    n += board_imu_begin() ? 1 : 0;
    n += board_baro_begin() ? 1 : 0;
    n += board_hum_begin() ? 1 : 0;
    return n;
}

bool sensors_imu_present()  { return board_imu_present(); }
bool sensors_baro_present() { return board_baro_present(); }
bool sensors_hum_present()  { return board_hum_present(); }

void sensors_read(sensors_t *s)
{
    if (s == nullptr)
    {
        return;
    }
    s->imu_ok  = board_imu_read(&s->imu);
    s->baro_ok = board_baro_read(&s->baro);
    s->hum_ok  = board_hum_read(&s->hum);
}

void sensors_print_imu(Print &out, const sensors_t &s)
{
    if (!s.imu_ok)
    {
        out.println("IMU ok=0");
        return;
    }
    out.printf("IMU ok=1 ax=%.2f ay=%.2f az=%.2f gx=%.3f gy=%.3f gz=%.3f t=%.1f\r\n", s.imu.ax,
               s.imu.ay, s.imu.az, s.imu.gx, s.imu.gy, s.imu.gz, s.imu.temp_c);
}

void sensors_print_baro(Print &out, const sensors_t &s)
{
    if (!s.baro_ok)
    {
        out.println("BARO ok=0");
        return;
    }
    out.printf("BARO ok=1 p=%.1f t=%.1f\r\n", s.baro.pressure_pa, s.baro.temp_c);
}

void sensors_print_hum(Print &out, const sensors_t &s)
{
    if (!s.hum_ok)
    {
        out.println("HUM ok=0");
        return;
    }
    out.printf("HUM ok=1 rh=%.1f t=%.1f\r\n", s.hum.rh, s.hum.temp_c);
}

void sensors_print_line(Print &out, const sensors_t &s, uint32_t seq)
{
    out.printf("SENS seq=%lu", (unsigned long)seq);
    if (s.hum_ok)
    {
        out.printf(" t=%.1f rh=%.1f", s.hum.temp_c, s.hum.rh);
    }
    else if (s.baro_ok)
    {
        out.printf(" t=%.1f", s.baro.temp_c);
    }
    if (s.baro_ok)
    {
        out.printf(" p=%.1f", s.baro.pressure_pa);
    }
    if (s.imu_ok)
    {
        out.printf(" ax=%.2f ay=%.2f az=%.2f gx=%.3f gy=%.3f gz=%.3f", s.imu.ax, s.imu.ay, s.imu.az,
                   s.imu.gx, s.imu.gy, s.imu.gz);
    }
    out.println();
}

/* append "key":value (value = "null" when !ok) - keeps sensors_json readable */
static size_t put(char *buf, size_t size, size_t at, const char *key, bool ok, float v, int decimals)
{
    if (at >= size)
    {
        return size;
    }
    int n = ok ? snprintf(buf + at, size - at, ",\"%s\":%.*f", key, decimals, (double)v)
               : snprintf(buf + at, size - at, ",\"%s\":null", key);
    return (n < 0) ? size : at + (size_t)n;
}

size_t sensors_json(char *buf, size_t size, const sensors_t &s, uint32_t seq, const char *board)
{
    if ((buf == nullptr) || (size == 0))
    {
        return 0;
    }
    int n0 = snprintf(buf, size, "{\"type\":\"cucumber\",\"board\":\"%s\",\"seq\":%lu", board,
                      (unsigned long)seq);
    size_t at = (n0 < 0) ? size : (size_t)n0;
    float  t  = s.hum_ok ? s.hum.temp_c : s.baro.temp_c;
    at = put(buf, size, at, "temperature", s.hum_ok || s.baro_ok, t, 2);
    at = put(buf, size, at, "humidity", s.hum_ok, s.hum.rh, 2);
    at = put(buf, size, at, "pressure", s.baro_ok, s.baro.pressure_pa, 1);
    at = put(buf, size, at, "acceleration_x", s.imu_ok, s.imu.ax, 3);
    at = put(buf, size, at, "acceleration_y", s.imu_ok, s.imu.ay, 3);
    at = put(buf, size, at, "acceleration_z", s.imu_ok, s.imu.az, 3);
    at = put(buf, size, at, "gyro_x", s.imu_ok, s.imu.gx, 4);
    at = put(buf, size, at, "gyro_y", s.imu_ok, s.imu.gy, 4);
    at = put(buf, size, at, "gyro_z", s.imu_ok, s.imu.gz, 4);
    if (at + 2 > size)
    {
        buf[0] = '\0';
        return 0;
    }
    buf[at++] = '}';
    buf[at]   = '\0';
    return at;
}
