case $(uname -n) in
transientscoatli)
  DIR=/usr/local/var/coatli/
  sudo mkdir -p $DIR
  sudo cp direct-coatli.sh $DIR/direct.sh
  ;;
ddoti6)
  DIR=/usr/local/var/ddoti/
  sudo mkdir -p $DIR
  sudo cp direct-ddoti.sh $DIR/direct.sh
  ;;
esac

(
  sudo crontab -l | grep -v direct
  echo "0,5,10,15,20,25,30,35,40,45,50,55 * * * * sh $DIR/direct.sh"
) | sudo crontab


  