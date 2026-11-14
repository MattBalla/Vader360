# Vader360

**Flydigi Vader 3 no Xbox 360 desbloqueado: um plugin DashLaunch para Bad Update / XeUnshackle (kernel 17559).**

[English](README.md)

O receptor do Flydigi Vader 3 (modo XInput, LED branco) se apresenta como um controle
de Xbox 360 (`045E:028E`), mas o kernel do 360 ainda o recusa. O driver de controle com
fio espera endpoints de 32 bytes e relatórios de entrada de 20 bytes, e o receptor usa
endpoints de 64 bytes e relatórios de 32. O XeUnshackle já libera controles XInput de
terceiros na checagem de segurança USB, e o Vader360 corrige as duas checagens que faltam.

O plugin é um `vader360.xex` separado. O XeUnshackle (ou XeUnshackle Max) continua o
oficial e nenhum outro arquivo precisa ser modificado.

## Recursos

- Dois patches de uma instrução cada no kernel, só na RAM. Eles somem ao desligar o console, como o próprio exploit.
- Antes de qualquer coisa, confere o código em volta de cada ponto de patch e **não altera nada**
  se algo for diferente do kernel 2.0.17559.0 ou se os patches já estiverem aplicados.
- Sem ponto flutuante, threads ou hooks: aplica os patches, registra no debug output e fica parado.
- Compilado pelo GitHub Actions com o toolchain livre [OpenXeChain](https://github.com/OpenXeChain), sem o XDK da Microsoft.

## Requisitos

- Xbox 360 no dashboard **2.0.17559.0**, com **Bad Update** ou **ABadAvatar** e
  **XeUnshackle** ou **[XeUnshackle Max](https://github.com/klofi/XeUnshackle-Max)**.
  Os dois carregam plugins do DashLaunch pelo `launch.ini`.
- Flydigi Vader 3 com o receptor 2.4 GHz no **modo XInput (LED branco)**.

## Instalação

1. Baixe o `Vader360-<versão>.zip` da [última release](../../releases/latest).
2. Copie `Plugins\vader360.xex` para o HD interno (`Hdd:\Plugins\`) ou para o pendrive (`Usb:\Plugins\`).
3. Coloque o plugin num slot livre da seção `[Plugins]` do `launch.ini` (na raiz do pendrive):

   ```ini
   [Plugins]
   plugin1 = Usb:\Xbdm.xex
   plugin2 = Hdd:\Plugins\vader360.xex
   ```

4. Rode o exploit normalmente. O DashLaunch carrega o plugin quando você sai do XeUnshackle.
5. Conecte o receptor **depois** de chegar no dashboard, ou desconecte e conecte de novo.
   O kernel só avalia o controle no momento em que ele é conectado.

## Como conferir se funcionou

Com o `Xbdm.xex` carregado, num PC com Windows:

```powershell
powershell -ExecutionPolicy Bypass -File vader360-check.ps1 -Ip <IP do console>
```

O script mostra se os dois patches estão ativos. Com `-Apply`, ele mesmo grava os patches
pelo XBDM, o que serve para testar sem o plugin. O plugin também escreve linhas `[Vader360] ...`
no debug output.

## Limitações

- Só funciona no kernel 2.0.17559.0. Em outro kernel, o plugin percebe a diferença e não faz nada.
- Testado com o receptor do Flydigi Vader 3. Outros receptores com o mesmo formato 64/32 bytes
  podem funcionar, mas não foram testados.
- O modo com fio (cabo USB-C) não foi testado.
- O plugin não reconecta os dispositivos. Conecte ou reconecte o receptor depois que ele carregar.

## Perguntas frequentes

**É permanente?** Não. O Bad Update não é persistente e o plugin também não é. Desligar o console
volta o kernel ao original.

**Ainda preciso de um XeUnshackle modificado?** Não. Use o `default.xex` oficial do XeUnshackle
ou do XeUnshackle Max e adicione este plugin.

**Pode estragar o console?** O plugin só grava duas instruções na RAM, depois de conferi-las.
Como qualquer homebrew, use por sua conta e risco.

## Compilação

Veja [docs/BUILDING.md](docs/BUILDING.md) (em inglês). Resumindo: num Linux com o OpenXeChain
e o `synthxex-patched`, rode `OXC=/opt/openxechain bash build.sh`. O resultado sai em `out/vader360.xex`.

## Créditos

- [Byrom90](https://github.com/Byrom90/XeUnshackle), pelo XeUnshackle e pelos patches Usbdsec, e
  [klofi](https://github.com/klofi/XeUnshackle-Max), pelo XeUnshackle Max.
- Os autores do Bad Update / ABadAvatar.
- [OpenXeChain](https://github.com/OpenXeChain) (fork do LLVM, xecorelib, SynthXEX).
- [Jacckii](https://github.com/Jacckii/Xbox360-Series-Controllers-Bridge), pelo patch de DLL de sistema
  do SynthXEX e pelas notas sobre o OpenXeChain. O CI baixa e roda esse patch, que não está incluído aqui.
- Desenvolvido com o apoio do [Claude](https://claude.ai) (Anthropic): engenharia reversa das checagens
  do kernel, código do plugin, CI e esta documentação.

Sem vínculo com a Microsoft ou a Flydigi. "Xbox 360" e "Vader 3" são marcas dos seus respectivos donos.

## Licença

[MIT](LICENSE).
