import pandas as pd
import matplotlib.pyplot as plt
import subprocess
import os


NACA_ID = 2412
UNIFORM_CURVE = True
CLEAN = True


if not os.path.exists('nacawings'):
    print('Executable not found.')

    if os.path.exists('NACAWINGS.F90'):
        print('Compiling airform former executable.')
        subprocess.run(['gfortran',
                        '-O3', '-march=native',
                        './NACAWINGS.F90',
                        '-o', 'nacawings'])
    else:
        print('Airfoil former source not found. Please get the main source code first.')
        exit(1)

if not os.path.exists('RESULTS.DAT'):
    proc = subprocess.run('./nacawings', input=f'{NACA_ID}\n', stdout=subprocess.DEVNULL, text=True, timeout=15)
else:
    CLEAN = False

df = pd.read_fwf(
    "RESULTS.DAT",
    skiprows=2,
    names=["XU", "YU", "XL", "YL"]
)

xu, yu = df["XU"], df["YU"]
xl, yl = df["XL"], df["YL"]

if (UNIFORM_CURVE):
    x = list(xu) + list(xl[::-1])
    y = list(yu) + list(yl[::-1])

    plt.figure()
    plt.plot(x, y)
    plt.gca().set_aspect('equal', adjustable='box')

    plt.show()
else:
    plt.figure()

    plt.plot(xu, yu)  # Upper surface
    plt.plot(xl, yl)  # Lower surface

    plt.gca().set_aspect('equal', adjustable='box')
    plt.xlabel("x")
    plt.ylabel("y")
    plt.title("Airfoil Section")

    plt.grid()

    plt.show()

if CLEAN:
    os.remove('./RESULTS.DAT')
    os.remove('./PROFILE.DAT')
    os.remove('./nacawings')
