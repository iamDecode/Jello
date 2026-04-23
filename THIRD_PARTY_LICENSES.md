# Third-party licenses

## Frida

`JelloInjector` statically links [Frida](https://github.com/frida/frida) via the
`frida-core-devkit` static library, fetched at build time from the Frida
GitHub release corresponding to `third_party/frida/VERSION`.

Frida is licensed under the **wxWindows Library Licence 3.1**, a variant of
the GNU Lesser General Public Licence 2.1 with a static-linking exception that
explicitly permits linking into proprietary programs without relicensing the
program itself.

Source code and the full licence text are available at
<https://github.com/frida/frida>.

If you want to relink `JelloInjector.app` against a modified build of Frida,
replace `third_party/frida/libfrida-core.a` and rebuild.
