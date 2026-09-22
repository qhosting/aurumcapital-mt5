"use client"

import Link from "next/link"
import { usePathname } from "next/navigation"
import { useSession, signOut } from "next-auth/react"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { Avatar, AvatarFallback } from "@/components/ui/avatar"
import { User, LogOut, Settings, TrendingUp, LayoutDashboard, LineChart, GraduationCap, ClipboardList } from "lucide-react"

export function DashboardHeader() {
  const { data: session } = useSession()
  const pathname = usePathname()

  const handleSignOut = () => {
    signOut({ callbackUrl: "/auth/signin" })
  }

  const navLinks = [
    {
      name: "Dashboard",
      href: "/app",
      icon: LayoutDashboard,
      active: pathname === "/app",
    },
    {
      name: "Mercado en Vivo",
      href: "/app/market",
      icon: LineChart,
      active: pathname.startsWith("/app/market"),
    },
    {
      name: "Academia & Estrategia",
      href: "/app/academy",
      icon: GraduationCap,
      active: pathname.startsWith("/app/academy"),
    },
    {
      name: "Plan de Trading",
      href: "/app/plan",
      icon: ClipboardList,
      active: pathname.startsWith("/app/plan"),
    },
  ]

  return (
    <header className="border-b border-gray-700 bg-[#12233A] sticky top-0 z-50">
      <div className="container mx-auto px-4">
        <div className="flex items-center justify-between h-16">
          {/* Logo and Nav Links */}
          <div className="flex items-center space-x-8">
            <Link href="/app" className="flex items-center space-x-2">
              <TrendingUp className="h-7 w-7 text-[#D4AF37]" />
              <div className="flex flex-col">
                <span className="text-base font-bold tracking-wider text-white">AURUM INVEST</span>
                <span className="text-[10px] text-[#D4AF37] font-mono tracking-widest -mt-1">STATION V15</span>
              </div>
            </Link>

            <nav className="hidden md:flex items-center space-x-1">
              {navLinks.map((link) => {
                const Icon = link.icon
                return (
                  <Link
                    key={link.href}
                    href={link.href}
                    className={`flex items-center space-x-2 px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
                      link.active
                        ? "bg-[#0A192F] text-[#D4AF37] border border-[#D4AF37]/30 shadow-sm"
                        : "text-gray-300 hover:text-white hover:bg-gray-800/60"
                    }`}
                  >
                    <Icon className={`h-4 w-4 ${link.active ? "text-[#D4AF37]" : "text-gray-400"}`} />
                    <span>{link.name}</span>
                  </Link>
                )
              })}
            </nav>
          </div>

          {/* User Menu */}
          <div className="flex items-center space-x-4">
            {session?.user && (
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button variant="ghost" className="relative h-9 w-9 rounded-full ring-1 ring-[#D4AF37]/30 hover:ring-[#D4AF37]">
                    <Avatar className="h-9 w-9">
                      <AvatarFallback className="bg-[#D4AF37] text-[#0A192F] font-bold text-xs">
                        {session.user.name?.charAt(0)?.toUpperCase() || "U"}
                      </AvatarFallback>
                    </Avatar>
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent className="w-56 bg-[#12233A] border-gray-700 shadow-xl" align="end" forceMount>
                  <DropdownMenuLabel className="font-normal">
                    <div className="flex flex-col space-y-1">
                      <p className="text-sm font-medium leading-none text-white">
                        {session.user.name}
                      </p>
                      <p className="text-xs leading-none text-gray-400">
                        {session.user.email}
                      </p>
                      <p className="text-xs leading-none text-[#D4AF37] capitalize font-mono">
                        {session.user.role?.toLowerCase()}
                      </p>
                    </div>
                  </DropdownMenuLabel>
                  <DropdownMenuSeparator className="bg-gray-700" />
                  <DropdownMenuItem asChild>
                    <Link href="/app" className="text-gray-300 hover:text-white hover:bg-gray-700 cursor-pointer flex items-center">
                      <LayoutDashboard className="mr-2 h-4 w-4" />
                      <span>Panel Principal</span>
                    </Link>
                  </DropdownMenuItem>
                  <DropdownMenuItem asChild>
                    <Link href="/app/market" className="text-gray-300 hover:text-white hover:bg-gray-700 cursor-pointer flex items-center">
                      <LineChart className="mr-2 h-4 w-4" />
                      <span>Gráfico en Vivo</span>
                    </Link>
                  </DropdownMenuItem>
                  <DropdownMenuItem asChild>
                    <Link href="/app/academy" className="text-gray-300 hover:text-white hover:bg-gray-700 cursor-pointer flex items-center">
                      <GraduationCap className="mr-2 h-4 w-4" />
                      <span>Academia de Trading</span>
                    </Link>
                  </DropdownMenuItem>
                  <DropdownMenuItem asChild>
                    <Link href="/app/plan" className="text-gray-300 hover:text-white hover:bg-gray-700 cursor-pointer flex items-center">
                      <ClipboardList className="mr-2 h-4 w-4" />
                      <span>Plan de Trading</span>
                    </Link>
                  </DropdownMenuItem>
                  <DropdownMenuSeparator className="bg-gray-700" />
                  <DropdownMenuItem 
                    onClick={handleSignOut}
                    className="text-rose-400 hover:text-rose-300 hover:bg-rose-500/10 cursor-pointer"
                  >
                    <LogOut className="mr-2 h-4 w-4" />
                    <span>Cerrar sesión</span>
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
            )}
          </div>
        </div>
      </div>
    </header>
  )
}
