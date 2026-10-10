import { Details } from "./components/Details";
import { Faq } from "./components/Faq";
import { Features } from "./components/Features";
import { ClosingCta, Footer } from "./components/Footer";
import { Hero } from "./components/Hero";
import { Install } from "./components/Install";
import { Nav } from "./components/Nav";
import { WhatsNew } from "./components/WhatsNew";

export function App() {
  return (
    <>
      <Nav />
      <main>
        <Hero />
        <WhatsNew />
        <Features />
        <Details />
        <Install />
        <Faq />
        <ClosingCta />
      </main>
      <Footer />
    </>
  );
}
