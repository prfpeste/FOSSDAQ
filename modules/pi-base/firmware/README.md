sudo apt update && sudo apt upgrade -y  
rm -rf firmware/  
git clone --no-checkout --depth 1 --branch Alexander_Gschlecht_Test https://github.com/prfpeste/FOSSDAQ.git  
cd FOSSDAQ  
git sparse-checkout init --cone  
git sparse-checkout set modules/pi-base/firmware  
git checkout  
cd ..  
mv FOSSDAQ/modules/pi-base/firmware ~/firmware  
rm -rf FOSSDAQ/  
rm firmware/README.md  
sudo bash firmware/install.sh  
sudo reboot now
