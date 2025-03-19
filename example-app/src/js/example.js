import { Adyen } from 'capacitor-adyen';

window.testEcho = () => {
    const inputValue = document.getElementById("echoInput").value;
    Adyen.echo({ value: inputValue })
}
