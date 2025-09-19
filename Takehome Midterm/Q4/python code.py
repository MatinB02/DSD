import numpy as np
import matplotlib.pyplot as plt
from scipy.signal import lfilter

# --- Load Verilog PWM Output ---
with open("pwm_output.txt") as f:
    pwm_signal = np.array([int(line.strip()) for line in f])

# --- Time settings ---
sample_rate = 50_000_000  # Match your Verilog clk freq (50 MHz)
dt = 1 / sample_rate
t = np.arange(len(pwm_signal)) * dt

# --- RC Filter ---
rc_time_constant = 0.002  # 2 ms
alpha = dt / (rc_time_constant + dt)
analog_output = lfilter([alpha], [1, alpha - 1], pwm_signal)

# --- Plot ---
plt.figure(figsize=(10, 6))
plt.plot(t * 1000, pwm_signal, label="PWM Output", alpha=0.3)
plt.plot(t * 1000, analog_output, label="Analog Output (RC Filter)", linewidth=2)
plt.xlabel("Time (ms)")
plt.ylabel("Voltage (normalized)")
plt.title("Verilog PWM Output + Simulated RC Filter")
plt.grid(True)
plt.legend()
plt.tight_layout()
plt.show()
