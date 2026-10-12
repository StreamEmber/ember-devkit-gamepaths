# ember-devkit-gamepaths

StreamEmber geliştirici kurulumu: GTA V ve Red Dead Redemption 2'nin kurulu olduğu klasörü bulur ve Windows
ortam değişkenine yazar. StreamEmber mod ve runtime projelerindeki `build.ps1` bu değişkenleri okur; derlediği
dosyaları doğrudan oyun klasörüne kurar.

| Script | Oyun | Yazdığı değişken | Klasörde olması gereken |
|---|---|---|---|
| `Set-GTAVPath.cmd` | Grand Theft Auto V (Legacy) | `GTAV_GAME_PATH` | `GTA5.exe` |
| `Set-RDR2Path.cmd` | Red Dead Redemption 2 | `RDR2_GAME_PATH` | `RDR2.exe` |

## Kullanım

1. Bu repoyu indirin (Code → Download ZIP ya da `git clone`).
2. `Set-GTAVPath.cmd` ve/veya `Set-RDR2Path.cmd` dosyasına çift tıklayın.
3. Sorulara cevap verin:
   - **A (otomatik):** Steam kütüphaneleri, Epic Games, Rockstar Games Launcher, Windows'ta yüklü programlar ve
     yaygın klasörler taranır. Bulunan klasör gösterilir ve doğru olup olmadığı sorulur. Birden fazla kurulum
     varsa numarasını seçersiniz.
   - **M (elle):** klasör yolunu yazarsınız (ör. `D:\EpicGames\GTAV`). Yolu tırnakla yapıştırmanız da olur;
     exe dosyasının yolunu yapıştırırsanız klasörü kendisi alır.
4. Açık terminal, Visual Studio ve Rider pencerelerini kapatıp yeniden açın. Artık projelerde `.\build.ps1`
   çalıştırınca mod derlenir ve oyun klasörüne kopyalanır.

Değişken **kullanıcı** ortam değişkeni olarak yazılır: yönetici izni gerekmez, yalnız sizin Windows hesabınızı
etkiler. Değeri sonradan görmek için: Başlat → "ortam değişkenleri" → *Hesabınızın ortam değişkenlerini düzenleyin*.

PowerShell'den de çalışır:

```powershell
.\Set-GamePath.ps1 -Game GTAV
.\Set-GamePath.ps1 -Game RDR2 -ListOnly   # yalnız bulunanları listeler, bir şey değiştirmez
```

GTA V Enhanced (`GTA5_Enhanced.exe`) kabul edilmez: ScriptHookV modlarımız Legacy sürümde (`GTA5.exe`) çalışır.
