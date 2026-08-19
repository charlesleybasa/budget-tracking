import { AppShell } from "@/components/AppShell";
import { WalletProvider } from "@/lib/store";

export default function Page() {
  return (
    <WalletProvider>
      <AppShell />
    </WalletProvider>
  );
}
